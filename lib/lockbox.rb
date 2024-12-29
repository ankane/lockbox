# stdlib
require "openssl"
require "securerandom"
require "stringio"

# modules
require_relative "lockbox/aes_gcm"
require_relative "lockbox/box"
require_relative "lockbox/calculations"
require_relative "lockbox/encryptor"
require_relative "lockbox/key_generator"
require_relative "lockbox/io"
require_relative "lockbox/migrator"
require_relative "lockbox/model"
require_relative "lockbox/padding"
require_relative "lockbox/utils"
require_relative "lockbox/version"

module Lockbox
  class Error < StandardError; end
  class DecryptionError < Error; end
  class PaddingError < Error; end

  autoload :Audit, "lockbox/audit"

  extend Padding

  class << self
    attr_accessor :default_options, :encode_attributes
    attr_writer :master_key
  end
  self.default_options = {}
  self.encode_attributes = true

  def self.master_key
    @master_key ||= ENV["LOCKBOX_MASTER_KEY"]
  end

  def self.migrate(relation, batch_size: 1000, restart: false)
    Migrator.new(relation, batch_size: batch_size).migrate(restart: restart)
  end

  def self.rotate(relation, batch_size: 1000, attributes:)
    Migrator.new(relation, batch_size: batch_size).rotate(attributes: attributes)
  end

  def self.generate_key
    SecureRandom.hex(32)
  end

  def self.generate_key_pair
    require "rbnacl"
    # encryption and decryption servers exchange public keys
    # this produces smaller ciphertext than sealed box
    alice = RbNaCl::PrivateKey.generate
    bob = RbNaCl::PrivateKey.generate
    # alice is sending message to bob
    # use bob first in both cases to prevent keys being swappable
    {
      encryption_key: to_hex(bob.public_key.to_bytes + alice.to_bytes),
      decryption_key: to_hex(bob.to_bytes + alice.public_key.to_bytes)
    }
  end

  def self.attribute_key(table:, attribute:, master_key: nil, encode: true)
    master_key ||= Lockbox.master_key
    raise ArgumentError, "Missing master key" unless master_key

    key = Lockbox::KeyGenerator.new(master_key).attribute_key(table: table, attribute: attribute)
    key = to_hex(key) if encode
    key
  end

  def self.to_hex(str)
    str.unpack1("H*")
  end

  def self.new(**options)
    Encryptor.new(**options)
  end

  def self.encrypts_action_text_body(**options)
    ActiveSupport.on_load(:action_text_rich_text) do
      ActionText::RichText.has_encrypted :body, **options
    end
  end
end

# integrations
require_relative "lockbox/carrier_wave_extensions" if defined?(CarrierWave)
require_relative "lockbox/railtie" if defined?(Rails)

if defined?(ActiveSupport::LogSubscriber)
  require_relative "lockbox/log_subscriber"
  Lockbox::LogSubscriber.attach_to :lockbox
end

if defined?(ActiveSupport.on_load)
  ActiveSupport.on_load(:active_record) do
    ar_version = ActiveRecord::VERSION::STRING.to_f
    if ar_version < 7
      if ar_version >= 5.2
        raise Lockbox::Error, "Active Record #{ActiveRecord::VERSION::STRING} requires Lockbox < 2"
      elsif ar_version >= 5
        raise Lockbox::Error, "Active Record #{ActiveRecord::VERSION::STRING} requires Lockbox < 0.7"
      else
        raise Lockbox::Error, "Active Record #{ActiveRecord::VERSION::STRING} not supported"
      end
    end

    extend Lockbox::Model
    extend Lockbox::Model::Attached
    ActiveRecord::Relation.prepend Lockbox::Calculations
  end

  ActiveSupport.on_load(:mongoid) do
    mongoid_version = Mongoid::VERSION.to_i
    if mongoid_version < 8
      if mongoid_version >= 6
        raise Lockbox::Error, "Mongoid #{Mongoid::VERSION} requires Lockbox < 2"
      else
        raise Lockbox::Error, "Mongoid #{Mongoid::VERSION} not supported"
      end
    end

    Mongoid::Document::ClassMethods.include(Lockbox::Model)
  end
end
