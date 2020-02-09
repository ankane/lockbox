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

  encrypts :email, previous_versions: [{key: Lockbox.generate_key}]

  key_pair = Lockbox.generate_key_pair
  encrypts :phone, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: key_pair[:decryption_key]

  encrypts :city, padding: true
  encrypts :ssn, encode: false
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
