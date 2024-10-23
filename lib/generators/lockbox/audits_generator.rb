require "rails/generators/active_record"

module Lockbox
  module Generators
    class AuditsGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration
      source_root File.join(__dir__, "templates")

      def copy_migration
        migration_template "migration.rb", "db/migrate/create_lockbox_audits.rb", migration_version: migration_version
        template "model.rb", "app/models/lockbox_audit.rb"
      end

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end

      def data_type
        case adapter
        when /postg/i # postgres, postgis
          "jsonb"
        when /mysql/i
          "json"
        else
          "text"
        end
      end

      # use connection_config instead of connection.adapter
      # so database connection isn't needed
      def adapter
        ActiveRecord::Base.connection_db_config.adapter.to_s
      end
    end
  end
end
