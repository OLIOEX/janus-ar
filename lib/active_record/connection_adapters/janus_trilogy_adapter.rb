# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/trilogy_adapter'
require_relative '../../janus'

module ActiveRecord
  module ConnectionHandling
    def janus_trilogy_connection(config)
      ActiveRecord::ConnectionAdapters::JanusTrilogyAdapter.new(config)
    end
  end
end

module ActiveRecord
  class Base
    def self.janus_trilogy_adapter_class
      ActiveRecord::ConnectionAdapters::JanusTrilogyAdapter
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class JanusTrilogyAdapter < ActiveRecord::ConnectionAdapters::TrilogyAdapter
      FOUND_ROWS = 'FOUND_ROWS'
      SQL_PRIMARY_MATCHERS = [
        /\A\s*select.+for update\Z/i, /select.+lock in share mode\Z/i,
        /\A\s*select.+(nextval|currval|lastval|get_lock|release_lock|pg_advisory_lock|pg_advisory_unlock)\(/i,
        /\A\s*show/i
      ].freeze
      SQL_REPLICA_MATCHERS = [/\A\s*(select|with.+\)\s*select)\s/i].freeze
      SQL_ALL_MATCHERS = [/\A\s*set\s/i].freeze
      SQL_SKIP_ALL_MATCHERS = [/\A\s*set\s+local\s/i].freeze
      WRITE_PREFIXES = %w(INSERT UPDATE DELETE LOCK CREATE GRANT DROP ALTER TRUNCATE FLUSH).freeze

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

        @replica_config = args[0][:janus]['replica'].symbolize_keys
        args[0] = args[0][:janus]['primary'].symbolize_keys

        super(*args)
        @connection_parameters ||= args[0]
        update_config
      end

      def raw_execute(sql, name, async: false, allow_retry: false, materialize_transactions: true)
        case where_to_send?(sql)
        when :all
          send_to_replica(sql, connection: :all, method: :execute)
          return super
        when :replica
          return send_to_replica(sql, connection: :replica, method: :execute)
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
          return super(sql)
        when :replica
          return send_to_replica(sql, connection: :replica, method: :execute)
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
          return super(sql, name, async:)
        when :replica
          return send_to_replica(sql, connection: :replica, method: :execute)
        else
          Janus::Context.stick_to_primary if write_query?(sql)
          Janus::Context.used_connection(:primary)
          return super(sql, name, async:)
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
        @replica_connection ||= ActiveRecord::ConnectionAdapters::TrilogyAdapter.new(@replica_config)
      end

      private

      def where_to_send?(sql)
        if should_send_to_all?(sql)
          :all
        elsif can_go_to_replica?(sql)
          :replica
        else
          :primary
        end
      end

      def should_send_to_all?(sql)
        SQL_ALL_MATCHERS.any? { |matcher| sql =~ matcher } && SQL_SKIP_ALL_MATCHERS.none? { |matcher| sql =~ matcher }
      end

      def can_go_to_replica?(sql)
        !should_go_to_primary?(sql)
      end

      def should_go_to_primary?(sql)
        Janus::Context.use_primary? ||
          write_query?(sql) ||
          open_transactions.positive? ||
          SQL_PRIMARY_MATCHERS.any? { |matcher| sql =~ matcher }
      end

      def send_to_replica(sql, connection: nil, method: :exec_query)
        Janus::Context.used_connection(connection) if connection
        if method == :execute
          replica_connection.execute(sql)
        else
          replica_connection.exec_query(sql)
        end
      end

      def write_query?(sql)
        WRITE_PREFIXES.include?(sql.upcase.split(' ').first)
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
