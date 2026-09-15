# frozen_string_literal: true

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

      # PostgreSQL never inlines bind values: ActiveRecord compiles statements
      # down to `$1` placeholders and hands the values to libpq separately, via
      # `exec_params` or `exec_prepared`. Replaying the SQL on its own - which is
      # all the MySQL adapters need - would reach the replica as placeholders
      # with no parameters, so we forward the whole call instead.
      #
      # `raw_execute` is private on a stock adapter, hence the `send`. We target
      # it rather than the public `execute` deliberately: the statement has
      # already been through `preprocess_query` on the way in, and running the
      # replica's public path would apply the query transformers a second time.
      def forward_raw_execute(sql, ...)
        replica_connection.send(:raw_execute, sql, ...)
      end
    end
  end
end
