# dependencies
require "openssl"
require "securerandom"

# modules
require "lockbox/box"
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

  def initialize(key: nil, algorithm: nil, previous_versions: nil)
    default_options = self.class.default_options
    key ||= default_options[:key]
    algorithm ||= default_options[:algorithm]
    previous_versions ||= default_options[:previous_versions]

    @boxes =
      [Box.new(key, algorithm: algorithm)] +
      Array(previous_versions).map { |v| Box.new(v[:key], algorithm: v[:algorithm]) }
  end

  def encrypt(message, **options)
    message = message.read if message.respond_to?(:read)
    @boxes.first.encrypt(message, **options)
  end

  def decrypt(ciphertext, **options)
    ciphertext = ciphertext.read if ciphertext.respond_to?(:read)
    raise TypeError, "can't convert ciphertext to string" unless ciphertext.respond_to?(:to_str)

    # ensure binary
    ciphertext = ciphertext.to_str
    if ciphertext.encoding != Encoding::BINARY
      # dup to prevent mutation
      ciphertext = ciphertext.dup.force_encoding(Encoding::BINARY)
    end

    @boxes.each_with_index do |box, i|
      begin
        return box.decrypt(ciphertext, **options)
      rescue => e
        error_classes = [DecryptionError]
        error_classes += [RbNaCl::LengthError, RbNaCl::CryptoError] if defined?(RbNaCl)
        if error_classes.any? { |ec| e.is_a?(ec) }
          raise DecryptionError, "Decryption failed" if i == @boxes.size - 1
        else
          raise e
        end
      end
    end
  end
end
