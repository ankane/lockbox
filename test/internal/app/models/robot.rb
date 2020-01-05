class Robot < ActiveRecord::Base
  default_scope { order(:id) }

  encrypts :name, :email, migrating: true
end
