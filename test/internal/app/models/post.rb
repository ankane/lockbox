class Post < ActiveRecord::Base
  encrypts :title
  validates :title, presence: true, length: {minimum: 3}
end
