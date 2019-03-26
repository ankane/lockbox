# dependencies
require "securerandom"

# modules
require "lockbox/box"
require "lockbox/encryptor"
require "lockbox/utils"
require "lockbox/version"

# integrations
require "lockbox/carrier_wave_extensions" if defined?(CarrierWave)
require "lockbox/railtie" if defined?(Rails)

class Lockbox
  class Error < StandardError; end
  class DecryptionError < Error; end

  class << self
    attr_accessor :default_options
  end
  self.default_options = {algorithm: "aes-gcm"}

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
      encryption_key: (bob.public_key.to_bytes + alice.to_bytes).unpack("H*").first,
      decryption_key: (bob.to_bytes + alice.public_key.to_bytes).unpack("H*").first
    }
  end

  private

  def check_string(str, name)
    str = str.read if str.respond_to?(:read)
    raise TypeError, "can't convert #{name} to string" unless str.respond_to?(:to_str)
    str.to_str
  end
end
