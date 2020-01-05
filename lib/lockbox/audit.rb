module Lockbox
  class Audit < ActiveRecord::Base
    self.table_name = "lockbox_audits"

    belongs_to :subject, polymorphic: true
    belongs_to :viewer, polymorphic: true
  end
end
