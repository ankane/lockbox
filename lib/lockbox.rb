# stdlib
require "base64"
require "openssl"
require "securerandom"

# modules
require "lockbox/aes_gcm"
require "lockbox/box"
require "lockbox/calculations"
require "lockbox/encryptor"
require "lockbox/key_generator"
require "lockbox/io"
require "lockbox/migrator"
require "lockbox/model"
require "lockbox/padding"
require "lockbox/utils"
require "lockbox/version"

# integrations
require "lockbox/carrier_wave_extensions" if defined?(CarrierWave)
require "lockbox/railtie" if defined?(Rails)

if defined?(ActiveSupport::LogSubscriber)
  require "lockbox/log_subscriber"
  Lockbox::LogSubscriber.attach_to :lockbox
end

if defined?(ActiveSupport.on_load)
  ActiveSupport.on_load(:active_record) do
    # TODO raise error in 0.7.0
    if ActiveRecord::VERSION::STRING.to_f <= 5.0
      warn "Active Record version (#{ActiveRecord::VERSION::STRING}) not supported in this version of Lockbox (#{Lockbox::VERSION})"
    end

    extend Lockbox::Model
    extend Lockbox::Model::Attached
    ActiveRecord::Calculations.prepend Lockbox::Calculations
  end

  ActiveSupport.on_load(:mongoid) do
    Mongoid::Document::ClassMethods.include(Lockbox::Model)
  end
end

module Lockbox
  class Error < StandardError; end
  class DecryptionError < Error; end
  class PaddingError < Error; end

  autoload :Audit, "lockbox/audit"
  autoload :Redis, "lockbox/redis"

  extend Padding

  class << self
    attr_accessor :default_options
    attr_writer :master_key
  end
  self.default_options = {}

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
    str.unpack("H*").first
  end

  def self.new(**options)
    Encryptor.new(**options)
  end

  def self.encrypts_action_text_body(**options)
    ActiveSupport.on_load(:action_text_rich_text) do
      ActionText::RichText.encrypts :body, **options
    end
  end
end
