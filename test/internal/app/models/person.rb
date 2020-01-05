class Person
  include Mongoid::Document

  field :name, type: String
  field :email_ciphertext, type: String
  field :phone_ciphertext, type: String
  field :ssn_ciphertext, type: BSON::Binary

  encrypts :email, previous_versions: [{key: Lockbox.generate_key}]

  key_pair = Lockbox.generate_key_pair
  encrypts :phone, algorithm: "hybrid", encryption_key: key_pair[:encryption_key], decryption_key: key_pair[:decryption_key]

  encrypts :ssn, encode: false
end
