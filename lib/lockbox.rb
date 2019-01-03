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
    unless message.respond_to?(:eof?)
      raise TypeError, "can't convert message to string" unless message.respond_to?(:to_str)
      message = StringIO.new(message.to_str)
    end
    @boxes.first.encrypt(message, **options)
  end

  def decrypt(ciphertext, **options)
    unless ciphertext.respond_to?(:eof?)
      raise TypeError, "can't convert ciphertext to string" unless ciphertext.respond_to?(:to_str)
      ciphertext = StringIO.new(ciphertext.to_str)
    end

    starting_pos = ciphertext.pos

    @boxes.each_with_index do |box, i|
      begin
        return box.decrypt(ciphertext, **options)
      rescue => e
        error_classes = [DecryptionError, Errno::EINVAL]
        error_classes += [RbNaCl::LengthError, RbNaCl::CryptoError] if defined?(RbNaCl)
        if error_classes.any? { |ec| e.is_a?(ec) }
          ciphertext.pos = starting_pos
          raise DecryptionError, "Decryption failed" if i == @boxes.size - 1
        else
          raise e
        end
      end
    end
  end
end
