require "shrine"
require "shrine/storage/file_system"

Shrine.storages = {
  cache: Shrine::Storage::FileSystem.new("/tmp", prefix: "cache"),
  store: Shrine::Storage::FileSystem.new("/tmp", prefix: "store"),
}

if mongoid?
  Shrine.plugin :mongoid
else
  Shrine.plugin :activerecord
end

Shrine.plugin :determine_mime_type

class PhotoUploader < Shrine
end
