module Lockbox
  module Padding
    PAD_FIRST_BYTE = "\x80".b
    PAD_ZERO_BYTE = "\x00".b

    def pad(str, **options)
      pad!(str.dup, **options)
    end

    def unpad(str, **options)
      unpad!(str.dup, **options)
    end

    # ISO/IEC 7816-4
    # same as Libsodium
    # https://libsodium.gitbook.io/doc/padding
    # apply prior to encryption
    # note: current implementation does not
    # try to minimize side channels
    def pad!(str, size: 16)
      raise ArgumentError, "Invalid size" if size < 1

      str.force_encoding(Encoding::BINARY)

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
    def unpad!(str, size: 16)
      raise ArgumentError, "Invalid size" if size < 1

      str.force_encoding(Encoding::BINARY)

      i = 1
      while i <= size
        case str[-i]
        when PAD_ZERO_BYTE
          i += 1
        when PAD_FIRST_BYTE
          str.slice!(-i..-1)
          return str
        else
          break
        end
      end

      raise Lockbox::PaddingError, "Invalid padding"
    end
  end
end
