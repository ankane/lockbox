class User < ActiveRecord::Base
  if respond_to?(:has_one_attached)
    has_one_attached :avatar
    encrypts_attached :avatar

    has_many_attached :avatars
    encrypts_attached :avatars

    has_one_attached :image
    has_many_attached :images
  end

  mount_uploader :document, DocumentUploader

  encrypts :email, previous_versions: [{key: Lockbox.generate_key}]

  key_pair = Lockbox.generate_key_pair
  encrypts :phone, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: key_pair[:decryption_key]

  serialize :properties, JSON
  serialize :properties2, JSON

  serialize :settings, Hash
  serialize :settings2, Hash
  serialize :info, Hash

  encrypts :properties2, :settings2

  encrypts :country2, type: :string
  encrypts :active2, type: :boolean
  encrypts :born_on2, type: :date
  encrypts :signed_at2, type: :datetime
  encrypts :opens_at2, type: :time
  encrypts :sign_in_count2, type: :integer
  encrypts :latitude2, type: :float
  encrypts :video2, type: :binary
  encrypts :data2, type: :json
  encrypts :info2, type: :hash
  encrypts :city, padding: true
  encrypts :ssn, encode: false
end
