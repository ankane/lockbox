class Post < ActiveRecord::Base
  has_one_attached :photo

  encrypts :title
  validates :title, presence: true, length: {minimum: 3}
end
