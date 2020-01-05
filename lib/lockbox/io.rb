module Lockbox
  class IO < StringIO
    attr_accessor :original_filename, :content_type
  end
end
