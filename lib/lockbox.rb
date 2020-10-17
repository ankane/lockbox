# stdlib
require "base64"
require "openssl"
require "securerandom"

# algorithms
require "lockbox/aes_gcm"
require "lockbox/curve25519_xsalsa20"
require "lockbox/xchacha20"
require "lockbox/xsalsa20"

# modules
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
  autoload :Libsodium, "lockbox/libsodium"

  extend Padding

  class << self
    attr_accessor :default_options, :libsodium_lib
    attr_writer :master_key
  end
  self.default_options = {}
  self.libsodium_lib =
    if Gem.win_platform?
      ["libsodium.dll", "sodium.dll"]
    elsif RbConfig::CONFIG["host_os"] =~ /darwin/i
      ["libsodium.dylib"]
    else
      ["libsodium.so", "libsodium.so.23", "libsodium.so.18"]
    end

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
    # encryption and decryption servers exchange public keys
    # this produces smaller ciphertext than sealed box
    alice = Curve25519XSalsa20.generate_key_pair
    bob = Curve25519XSalsa20.generate_key_pair
    # alice is sending message to bob
    # use bob first in both cases to prevent keys being swappable
    {
      encryption_key: to_hex(bob[:pk] + alice[:sk]),
      decryption_key: to_hex(bob[:sk] + alice[:pk])
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
