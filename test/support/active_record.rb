require "active_record"

# for debugging
ActiveRecord::Base.logger = $logger

# migrations
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: ":memory:"
