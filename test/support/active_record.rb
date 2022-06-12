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

  has_encrypted :email, previous_versions: [{key: Lockbox.generate_key}, {master_key: Lockbox.generate_key}]

  key_pair = Lockbox.generate_key_pair
  has_encrypted :phone, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: key_pair[:decryption_key]

  serialize :properties, JSON
  serialize :properties2, JSON

  serialize :settings, Hash
  serialize :settings2, Hash

  serialize :messages, Array
  serialize :messages2, Array

  has_encrypted :properties2, :settings2, :messages2

  serialize :info, Hash
  serialize :coordinates, Array

  store :credentials, accessors: [:username], coder: JSON
  store :credentials2, accessors: [:username2], coder: JSON
  has_encrypted :credentials2

  attribute :configuration, Configuration.new
  has_encrypted :configuration2, type: Configuration.new

  attribute :config, Configuration.new
  attribute :config2, Configuration.new
  has_encrypted :config2

  attribute :conf, Configuration.new
  has_encrypted :conf, migrating: true

  has_encrypted :country2, type: :string
  has_encrypted :active2, type: :boolean
  has_encrypted :born_on2, type: :date
  has_encrypted :signed_at2, type: :datetime
  has_encrypted :opens_at2, type: :time
  has_encrypted :sign_in_count2, type: :integer
  has_encrypted :latitude2, type: :float
  has_encrypted :video2, type: :binary
  has_encrypted :data2, type: :json
  has_encrypted :info2, type: :hash
  has_encrypted :coordinates2, type: :array

  if ENV["ADAPTER"] == "postgresql"
    has_encrypted :ip2, type: :inet
  end

  has_encrypted :city, padding: true
  has_encrypted :ssn, encode: false

  has_encrypted :state

  has_rich_text :content if respond_to?(:has_rich_text)

  include PhotoUploader::Attachment(:photo)
end

class Post < ActiveRecord::Base
  has_encrypted :title
  validates :title, presence: true, length: {minimum: 3}

  if respond_to?(:has_one_attached)
    has_one_attached :photo
  end
end

class Robot < ActiveRecord::Base
  default_scope { order(:id) }

  serialize :properties, JSON

  has_encrypted :name, :email, :properties, migrating: true
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
  has_encrypted :email, key: :record_key
  has_encrypted :personal_email, key: -> { record_key }
  has_encrypted :other_email, key: -> { "2"*64 }

  def record_key
    "1"*64
  end

  has_encrypted :email_address, key_table: "users", key_attribute: "email_ciphertext", previous_versions: [{key_table: "people", key_attribute: "email_ciphertext"}]
  has_encrypted :work_email, encrypted_attribute: "encrypted_email"

  attribute :code, :string, default: -> { "hello" }
end

class Agent < ActiveRecord::Base
  key_pair = Lockbox.generate_key_pair
  has_encrypted :email, algorithm: "hybrid", encryption_key: key_pair[:encryption_key]
end

class Person < ActiveRecord::Base
  has_encrypted :data, type: :json

  before_save :update_data

  def update_data
    data["count"] += 1
  end
end

# ensure has_encrypted does not cause model schema to load
raise "has_encrypted loading model schema early" if Person.send(:schema_loaded?)
