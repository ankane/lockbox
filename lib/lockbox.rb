# dependencies
require "securerandom"

# modules
require "lockbox/box"
require "lockbox/encryptor"
require "lockbox/key_generator"
require "lockbox/utils"
require "lockbox/version"

# integrations
require "lockbox/carrier_wave_extensions" if defined?(CarrierWave)
require "lockbox/railtie" if defined?(Rails)

if defined?(ActiveSupport)
  ActiveSupport.on_load(:active_record) do
    require "lockbox/model"
    extend Lockbox::Model
  end
end

class Lockbox
  class Error < StandardError; end
  class DecryptionError < Error; end
  class PaddingError < Error; end

  class << self
    attr_accessor :default_options
    attr_writer :master_key
  end
  self.default_options = {}

  def self.master_key
    @master_key ||= ENV["LOCKBOX_MASTER_KEY"]
  end

  def self.migrate(model, restart: false)
    # get fields
    fields = model.lockbox_attributes.select { |k, v| v[:migrating] }

    # get blind indexes
    blind_indexes = model.respond_to?(:blind_indexes) ? model.blind_indexes.select { |k, v| v[:migrating] } : {}

    # build relation
    relation = model.unscoped

    unless restart
      attributes = fields.map { |_, v| v[:encrypted_attribute] }
      attributes += blind_indexes.map { |_, v| v[:bidx_attribute] }

      attributes.each_with_index do |attribute, i|
        relation =
          if i == 0
            relation.where(attribute => nil)
          else
            relation.or(model.where(attribute => nil))
          end
      end
    end

    # migrate
    relation.find_each do |record|
      fields.each do |k, v|
        record.send("#{v[:attribute]}=", record.send(k)) if restart || !record.send(v[:encrypted_attribute])
      end
      blind_indexes.each do |k, v|
        record.send("compute_#{k}_bidx") if restart || !record.send(v[:bidx_attribute])
      end
      record.save(validate: false) if record.changed?
    end
  end

  def initialize(**options)
    options = self.class.default_options.merge(options)
    previous_versions = options.delete(:previous_versions)

    @boxes =
      [Box.new(options)] +
      Array(previous_versions).map { |v| Box.new(v) }
  end

  def encrypt(message, **options)
    message = check_string(message, "message")
    @boxes.first.encrypt(message, **options)
  end

  def decrypt(ciphertext, **options)
    ciphertext = check_string(ciphertext, "ciphertext")

    # ensure binary
    if ciphertext.encoding != Encoding::BINARY
      # dup to prevent mutation
      ciphertext = ciphertext.dup.force_encoding(Encoding::BINARY)
    end

    @boxes.each_with_index do |box, i|
      begin
        return box.decrypt(ciphertext, **options)
      rescue => e
        error_classes = [DecryptionError]
        error_classes << RbNaCl::LengthError if defined?(RbNaCl::LengthError)
        error_classes << RbNaCl::CryptoError if defined?(RbNaCl::CryptoError)
        if error_classes.any? { |ec| e.is_a?(ec) }
          raise DecryptionError, "Decryption failed" if i == @boxes.size - 1
        else
          raise e
        end
      end
    end
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

  PAD_BLOCK_SIZE = 16
  PAD_FIRST_BYTE = "\x80".b
  PAD_ZERO_BYTE = "\x00".b

  # ISO/IEC 7816-4
  # same as Libsodium
  # https://libsodium.gitbook.io/doc/padding
  # apply prior to encryption
  # TODO minimize side channels
  def self.pad(str)
    str = str.dup.force_encoding(Encoding::BINARY)

    pad_length = PAD_BLOCK_SIZE - 1
    pad_length -= str.bytesize % PAD_BLOCK_SIZE

    str << PAD_FIRST_BYTE
    pad_length.times do
      str << PAD_ZERO_BYTE
    end

    str
  end

  def self.unpad(str)
    if str.encoding != Encoding::BINARY
      str = str.dup.force_encoding(Encoding::BINARY)
    end

    i = 1
    while i <= PAD_BLOCK_SIZE
      case str[-i]
      when PAD_ZERO_BYTE
        i += 1
      when PAD_FIRST_BYTE
        return str[0..-(i + 1)]
      else
        break
      end
    end

    raise Lockbox::PaddingError, "Invalid padding"
  end

  private

  def check_string(str, name)
    str = str.read if str.respond_to?(:read)
    raise TypeError, "can't convert #{name} to string" unless str.respond_to?(:to_str)
    str.to_str
  end
end
