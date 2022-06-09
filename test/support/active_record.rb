require "active_record"

ActiveRecord::Base.logger = $logger

class User < ActiveRecord::Base
  class Configuration < ActiveModel::Type::String
    def serialize(value)
      "#{value}!!"
    end

    def deserialize(value)
      return if value.nil?
      value[0..-3].force_encoding(Encoding::UTF_8)
    end
  end

  if respond_to?(:has_one_attached)
    has_one_attached :avatar
    encrypts_attached :avatar

    has_many_attached :avatars
    encrypts_attached :avatars

    has_one_attached :image
    has_many_attached :images
  end

  mount_uploader :document, DocumentUploader
  mount_uploaders :documents, DocumentUploader
  serialize :documents, JSON

  lockbox_encrypts :email, previous_versions: [{key: Lockbox.generate_key}, {master_key: Lockbox.generate_key}]

  key_pair = Lockbox.generate_key_pair
  lockbox_encrypts :phone, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: key_pair[:decryption_key]

  serialize :properties, JSON
  serialize :properties2, JSON

  serialize :settings, Hash
  serialize :settings2, Hash

  serialize :messages, Array
  serialize :messages2, Array

  lockbox_encrypts :properties2, :settings2, :messages2

  serialize :info, Hash
  serialize :coordinates, Array

  store :credentials, accessors: [:username], coder: JSON
  store :credentials2, accessors: [:username2], coder: JSON
  lockbox_encrypts :credentials2

  attribute :configuration, Configuration.new
  lockbox_encrypts :configuration2, type: Configuration.new

  attribute :config, Configuration.new
  attribute :config2, Configuration.new
  lockbox_encrypts :config2

  attribute :conf, Configuration.new
  lockbox_encrypts :conf, migrating: true

  lockbox_encrypts :country2, type: :string
  lockbox_encrypts :active2, type: :boolean
  lockbox_encrypts :born_on2, type: :date
  lockbox_encrypts :signed_at2, type: :datetime
  lockbox_encrypts :opens_at2, type: :time
  lockbox_encrypts :sign_in_count2, type: :integer
  lockbox_encrypts :latitude2, type: :float
  lockbox_encrypts :video2, type: :binary
  lockbox_encrypts :data2, type: :json
  lockbox_encrypts :info2, type: :hash
  lockbox_encrypts :coordinates2, type: :array

  if ENV["ADAPTER"] == "postgresql"
    lockbox_encrypts :ip2, type: :inet
  end

  lockbox_encrypts :city, padding: true
  lockbox_encrypts :ssn, encode: false

  lockbox_encrypts :state

  has_rich_text :content if respond_to?(:has_rich_text)

  include PhotoUploader::Attachment(:photo)
end

class Post < ActiveRecord::Base
  lockbox_encrypts :title
  validates :title, presence: true, length: {minimum: 3}

  if respond_to?(:has_one_attached)
    has_one_attached :photo
  end
end

class Robot < ActiveRecord::Base
  default_scope { order(:id) }

  serialize :properties, JSON

  lockbox_encrypts :name, :email, :properties, migrating: true
end

class Comment < ActiveRecord::Base
  if respond_to?(:has_one_attached)
    has_one_attached :image
    has_many_attached :images
  end

  # not a field, but add lockbox_attachments to model
  encrypts_attached :hack
end

class Admin < ActiveRecord::Base
  lockbox_encrypts :email, key: :record_key
  lockbox_encrypts :personal_email, key: -> { record_key }
  lockbox_encrypts :other_email, key: -> { "2"*64 }

  def record_key
    "1"*64
  end

  lockbox_encrypts :email_address, key_table: "users", key_attribute: "email_ciphertext", previous_versions: [{key_table: "people", key_attribute: "email_ciphertext"}]
  lockbox_encrypts :work_email, encrypted_attribute: "encrypted_email"

  attribute :code, :string, default: -> { "hello" }
end

class Agent < ActiveRecord::Base
  key_pair = Lockbox.generate_key_pair
  lockbox_encrypts :email, algorithm: "hybrid", encryption_key: key_pair[:encryption_key]
end

class Person < ActiveRecord::Base
  lockbox_encrypts :data, type: :json

  before_save :update_data

  def update_data
    data["count"] += 1
  end
end

# ensure encrypts does not cause model schema to load
raise "encrypts loading model schema early" if Person.send(:schema_loaded?)
