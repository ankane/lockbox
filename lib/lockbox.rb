# dependencies
require "openssl"
require "securerandom"

# modules
require "lockbox/box"
require "lockbox/encryptor"
require "lockbox/key_generator"
require "lockbox/io"
require "lockbox/migrator"
require "lockbox/model"
require "lockbox/utils"
require "lockbox/version"

# integrations
require "lockbox/carrier_wave_extensions" if defined?(CarrierWave)
require "lockbox/railtie" if defined?(Rails)

if defined?(ActiveSupport)
  ActiveSupport.on_load(:active_record) do
    extend Lockbox::Model
  end

  ActiveSupport.on_load(:mongoid) do
    Mongoid::Document::ClassMethods.include(Lockbox::Model)
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
    Migrator.new(model).migrate(restart: restart)
  end

  def initialize(**options)
    options = self.class.default_options.merge(options)
    previous_versions = options.delete(:previous_versions)

    @boxes =
      [Box.new(options)] +
      Array(previous_versions).map { |v| Box.new({key: options[:key]}.merge(v)) }
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
        # returning DecryptionError instead of PaddingError
        # is for end-user convenience, not for security
        error_classes = [DecryptionError, PaddingError]
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

  def encrypt_io(io, **options)
    new_io = Lockbox::IO.new(encrypt(io.read, **options))
    copy_metadata(io, new_io)
    new_io
  end

  def decrypt_io(io, **options)
    new_io = Lockbox::IO.new(decrypt(io.read, **options))
    copy_metadata(io, new_io)
    new_io
  end

  def decrypt_str(ciphertext, **options)
    message = decrypt(ciphertext, **options)
    message.force_encoding(Encoding::UTF_8)
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

  PAD_FIRST_BYTE = "\x80".b
  PAD_ZERO_BYTE = "\x00".b

  # ISO/IEC 7816-4
  # same as Libsodium
  # https://libsodium.gitbook.io/doc/padding
  # apply prior to encryption
  # note: current implementation does not
  # try to minimize side channels
  def self.pad(str, size: 16)
    raise ArgumentError, "Invalid size" if size < 1

    str = str.dup.force_encoding(Encoding::BINARY)

    pad_length = size - 1
    pad_length -= str.bytesize % size

    str << PAD_FIRST_BYTE
    pad_length.times do
      str << PAD_ZERO_BYTE
    end

    str
  end

  # note: current implementation does not
  # try to minimize side channels
  def self.unpad(str, size: 16)
    raise ArgumentError, "Invalid size" if size < 1

    if str.encoding != Encoding::BINARY
      str = str.dup.force_encoding(Encoding::BINARY)
    end

    i = 1
    while i <= size
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

  def copy_metadata(source, target)
    target.original_filename =
      if source.respond_to?(:original_filename)
        source.original_filename
      elsif source.respond_to?(:path)
        File.basename(source.path)
      end
    target.content_type = source.content_type if source.respond_to?(:content_type)
  end
end
