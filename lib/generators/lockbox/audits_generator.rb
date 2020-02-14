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

      def info_type
        # use connection_config instead of connection.adapter
        # so database connection isn't needed
        case ActiveRecord::Base.connection_config[:adapter].to_s
        when /postg/i # postgres, postgis
          "jsonb"
        when /mysql/i
          "json"
        else
          "text"
        end
      end
    end
  end
end
