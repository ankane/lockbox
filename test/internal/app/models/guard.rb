class Guard
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic
  store_in collection: "people"
end
