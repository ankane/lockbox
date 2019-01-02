class User < ActiveRecord::Base
  has_one_attached :avatar
  attached_encrypted :avatar, key: SecureRandom.random_bytes(32)

  has_many_attached :avatars
  attached_encrypted :avatars, key: SecureRandom.random_bytes(32)

  has_one_attached :image
  has_many_attached :images

  mount_uploader :document, DocumentUploader
end
