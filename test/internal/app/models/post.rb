class Post < ActiveRecord::Base
  encrypts :title
  validates :title, presence: true
end
