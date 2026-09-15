require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/postgresql_adapter'
require_relative '../../../janus-ar'
require_relative '../../adapter_extensions'

module ActiveRecord
  module ConnectionHandling
    def janus_postgresql_connection(config)
      ActiveRecord::ConnectionAdapters::JanusPostgreSQLAdapter.new(config)
    end
  end

  class Base
    def self.janus_postgresql_adapter_class
      ActiveRecord::ConnectionAdapters::JanusPostgreSQLAdapter
    end
  end

  module ConnectionAdapters
    class JanusPostgreSQLAdapter < ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      include Janus::AdapterExtensions

      private

      def replica_adapter_class
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
      end

      # PostgreSQL compiles statements to `$1` placeholders and passes the values
      # separately, so the replica needs the whole call, not just the SQL.
      #
      # `raw_execute` is private on a stock adapter, hence the `send`. It is the
      # right target rather than the public `execute`: the statement has already
      # been through `preprocess_query`, which we do not want applied twice.
      def forward_raw_execute(sql, ...)
        replica_connection.send(:raw_execute, sql, ...)
      end
    end
  end
end
