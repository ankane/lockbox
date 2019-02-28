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

  private

  def check_string(str, name)
    str = str.read if str.respond_to?(:read)
    raise TypeError, "can't convert #{name} to string" unless str.respond_to?(:to_str)
    str.to_str
  end
end
