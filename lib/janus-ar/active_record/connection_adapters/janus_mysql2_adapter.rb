# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'
require_relative '../../../janus-ar'

module ActiveRecord
  module ConnectionHandling
    def janus_mysql2_connection(config)
      ActiveRecord::ConnectionAdapters::JanusMysql2Adapter.new(config)
    end
  end
end

module ActiveRecord
  class Base
    def self.janus_mysql2_adapter_class
      ActiveRecord::ConnectionAdapters::JanusMysql2Adapter
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class JanusMysql2Adapter < ActiveRecord::ConnectionAdapters::Mysql2Adapter
      FOUND_ROWS = 'FOUND_ROWS'

      attr_reader :config

      class << self
        def dbconsole(config, options = {})
          connection_config = Janus::DbConsoleConfig.new(config)

          super(connection_config, options)
        end
      end

      def initialize(*args)
        args[0][:janus]['replica']['database'] = args[0][:database]
        args[0][:janus]['primary']['database'] = args[0][:database]

        @replica_config = args[0][:janus]['replica']
        args[0] = args[0][:janus]['primary']

        super(*args)
        @connection_parameters ||= args[0]
        update_config
      end

      def with_connection(_args = {})
        self
      end

      def raw_execute(sql, name = nil, binds = [], prepare: false, async: false, allow_retry: false,
        materialize_transactions: true, batch: false)
        case where_to_send?(sql)
        when :all
          send_to_replica(sql, connection: :all, method: :raw_execute)
          super
        when :replica
          send_to_replica(sql, connection: :replica, method: :raw_execute)
        else
          Janus::Context.stick_to_primary if write_query?(sql)
          Janus::Context.used_connection(:primary)
          super
        end
      end

      def execute(sql)
        case where_to_send?(sql)
        when :all
          send_to_replica(sql, connection: :all, method: :execute)
          super(sql)
        when :replica
          send_to_replica(sql, connection: :replica, method: :execute)
        else
          Janus::Context.stick_to_primary if write_query?(sql)
          Janus::Context.used_connection(:primary)
          super(sql)
        end
      end

      def execute_and_free(sql, name = nil, async: false)
        case where_to_send?(sql)
        when :all
          send_to_replica(sql, connection: :all, method: :execute)
          super(sql, name, async:)
        when :replica
          send_to_replica(sql, connection: :replica, method: :execute)
        else
          Janus::Context.stick_to_primary if write_query?(sql)
          Janus::Context.used_connection(:primary)
          super(sql, name, async:)
        end
      end

      def connect!(...)
        replica_connection.connect!(...)
        super
      end

      def reconnect!(...)
        replica_connection.reconnect!(...)
        super
      end

      def disconnect!(...)
        replica_connection.disconnect!(...)
        super
      end

      def clear_cache!(...)
        replica_connection.clear_cache!(...)
        super
      end

      def replica_connection
        @replica_connection ||= ActiveRecord::ConnectionAdapters::Mysql2Adapter.new(@replica_config)
      end

      private

      def where_to_send?(sql)
        Janus::QueryDirector.new(sql, open_transactions).where_to_send?
      end

      def send_to_replica(sql, connection: nil, method: :exec_query)
        Janus::Context.used_connection(connection) if connection
        if method == :execute
          replica_connection.execute(sql)
        elsif method == :raw_execute
          replica_connection.execute(sql)
        else
          replica_connection.exec_query(sql)
        end
      end

      def update_config
        @config[:flags] ||= 0

        if @config[:flags].is_a? Array
          @config[:flags].push FOUND_ROWS
        else
          @config[:flags] |= ::Janus::Client::FOUND_ROWS
        end
      end
    end
  end
end
