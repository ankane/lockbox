Mongoid.logger = $logger
Mongo::Logger.logger = $logger if defined?(Mongo::Logger)

Mongoid.configure do |config|
  config.connect_to "lockbox_test"
end

class User
  include Mongoid::Document

  field :name, type: String
  field :email_ciphertext, type: String
  field :phone_ciphertext, type: String
  field :city_ciphertext, type: String
  field :ssn_ciphertext, type: BSON::Binary
  field :state, type: String
  field :state_ciphertext, type: String

  encrypts :email, previous_versions: [{key: Lockbox.generate_key}, {master_key: Lockbox.generate_key}]

  key_pair = Lockbox.generate_key_pair
  encrypts :phone, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: key_pair[:decryption_key]

  encrypts :city, padding: true
  encrypts :ssn, encode: false
  encrypts :state

  include PhotoUploader::Attachment(:photo)
  field :photo_data, type: String
end

class Guard
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  store_in collection: "users"
end

class Post
  include Mongoid::Document

  field :title_ciphertext, type: String

  encrypts :title
  validates :title, presence: true, length: {minimum: 3}
end

class Robot
  include Mongoid::Document

  field :name, type: String
  field :email, type: String
  field :name_ciphertext, type: String
  field :email_ciphertext, type: String

  encrypts :name, :email, migrating: true
end

class Admin
  include Mongoid::Document

  field :name, type: String
  field :email_ciphertext, type: String
  field :email_address_ciphertext, type: String
  field :encrypted_email, type: String

  encrypts :email, key: :record_key
  encrypts :personal_email, key: -> { record_key }
  encrypts :other_email, key: -> { "2"*64 }

  def record_key
    "1"*64
  end

  encrypts :email_address, key_table: "users", key_attribute: "email_ciphertext", previous_versions: [{key_table: "people", key_attribute: "email_ciphertext"}]
  encrypts :work_email, encrypted_attribute: "encrypted_email"
end

class Agent
  include Mongoid::Document

  field :name, type: String
  field :email_ciphertext, type: String

  key_pair = Lockbox.generate_key_pair
  encrypts :email, algorithm: "hybrid", encryption_key: key_pair[:encryption_key]
end
