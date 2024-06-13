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
  field :region_ciphertext, type: String
  field :state, type: String
  field :state_ciphertext, type: String

  has_encrypted :email, previous_versions: [{key: Lockbox.generate_key}, {master_key: Lockbox.generate_key}]

  key_pair = Lockbox.generate_key_pair
  has_encrypted :phone, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: key_pair[:decryption_key]

  has_encrypted :city, padding: true
  has_encrypted :ssn, encode: false
  has_encrypted :region, associated_data: -> { name }
  has_encrypted :state

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

  has_encrypted :title
  validates :title, presence: true, length: {minimum: 3}
end

class Robot
  include Mongoid::Document

  field :name, type: String
  field :email, type: String
  field :name_ciphertext, type: String
  field :email_ciphertext, type: String

  has_encrypted :name, :email, migrating: true
end

class Admin
  include Mongoid::Document

  field :name, type: String
  field :email_ciphertext, type: String
  field :personal_email_ciphertext, type: String
  field :other_email_ciphertext, type: String
  field :email_address_ciphertext, type: String
  field :encrypted_email, type: String
  field :dep_ciphertext, type: String
  field :dep2_ciphertext, type: String

  has_encrypted :email, key: :record_key
  has_encrypted :personal_email, key: -> { record_key }
  has_encrypted :other_email, key: -> { "2"*64 }

  def record_key
    "1"*64
  end

  has_encrypted :email_address, key_table: "users", key_attribute: "email_ciphertext", previous_versions: [{key_table: "people", key_attribute: "email_ciphertext"}]
  has_encrypted :work_email, encrypted_attribute: "encrypted_email"
end

class Agent
  include Mongoid::Document

  field :name, type: String
  field :email_ciphertext, type: String
  field :personal_email_ciphertext, type: String

  key_pair = Lockbox.generate_key_pair
  has_encrypted :email, algorithm: "hybrid", encryption_key: key_pair[:encryption_key]
  has_encrypted :personal_email, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: -> { nil }
end
