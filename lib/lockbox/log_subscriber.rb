module Lockbox
  class LogSubscriber < ActiveSupport::LogSubscriber
    def encrypt_file(event)
      return unless logger.debug?

      payload = event.payload
      name = "Encrypt File (#{event.duration.round(1)}ms)"

      debug "  #{color(name, YELLOW, bold: true)} Encrypted #{payload[:name]}"
    end

    def decrypt_file(event)
      return unless logger.debug?

      payload = event.payload
      name = "Decrypt File (#{event.duration.round(1)}ms)"

      debug "  #{color(name, YELLOW, bold: true)} Decrypted #{payload[:name]}"
    end
  end
end
