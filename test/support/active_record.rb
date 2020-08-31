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

  encrypts :email, previous_versions: [{key: Lockbox.generate_key}, {master_key: Lockbox.generate_key}]

  key_pair = Lockbox.generate_key_pair
  encrypts :phone, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: key_pair[:decryption_key]

  serialize :properties, JSON
  serialize :properties2, JSON

  serialize :settings, Hash
  serialize :settings2, Hash

  serialize :messages, Array
  serialize :messages2, Array

  encrypts :properties2, :settings2, :messages2

  serialize :info, Hash
  serialize :coordinates, Array

  store :credentials, accessors: [:username], coder: JSON
  store :credentials2, accessors: [:username2], coder: JSON
  encrypts :credentials2

  attribute :configuration, Configuration.new
  encrypts :configuration2, type: Configuration.new

  attribute :config, Configuration.new
  attribute :config2, Configuration.new
  encrypts :config2

  attribute :conf, Configuration.new
  encrypts :conf, migrating: true

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
  encrypts :coordinates2, type: :array
  encrypts :city, padding: true
  encrypts :ssn, encode: false

  encrypts :state

  has_rich_text :content if respond_to?(:has_rich_text)
end

class Post < ActiveRecord::Base
  encrypts :title
  validates :title, presence: true, length: {minimum: 3}

  if respond_to?(:has_one_attached)
    has_one_attached :photo
  end
end

class Robot < ActiveRecord::Base
  default_scope { order(:id) }

  serialize :properties, JSON

  encrypts :name, :email, :properties, migrating: true
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
  encrypts :email, key: :record_key

  def record_key
    "1"*64
  end

  encrypts :email_address, key_table: "users", key_attribute: "email_ciphertext"
end

class Agent < ActiveRecord::Base
  key_pair = Lockbox.generate_key_pair
  encrypts :email, algorithm: "hybrid", encryption_key: key_pair[:encryption_key]
end
