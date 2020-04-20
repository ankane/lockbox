module Lockbox
  class IO < StringIO
    attr_accessor :original_filename, :content_type

    # private: do not use
    attr_accessor :extracted_content_type
  end
end
