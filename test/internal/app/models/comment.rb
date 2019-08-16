class Comment
  include Mongoid::Document

  field :title_ciphertext, type: String

  encrypts :title
  validates :title, presence: true, length: {minimum: 3}
end
