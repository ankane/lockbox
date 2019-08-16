class Dog
  include Mongoid::Document

  field :name, type: String
  field :email, type: String
  field :name_ciphertext, type: String
  field :email_ciphertext, type: String

  encrypts :name, :email, migrating: true
end
