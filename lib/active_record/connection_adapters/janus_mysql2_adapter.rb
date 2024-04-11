# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'
require_relative '../../janus'

module ActiveRecord
  module ConnectionHandling
    def janus_mysql2_connection(config)
      ActiveRecord::ConnectionAdapters::JanusMysql2Adapter.new(config)
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class JanusMysql2Adapter < ActiveRecord::ConnectionAdapters::Mysql2Adapter
      FOUND_ROWS = 'FOUND_ROWS'
      SQL_PRIMARY_MATCHERS = [
        /\A\s*select.+for update\Z/i, /select.+lock in share mode\Z/i,
        /\A\s*select.+(nextval|currval|lastval|get_lock|release_lock|pg_advisory_lock|pg_advisory_unlock)\(/i,
        /\A\s*show/i
      ].freeze
      SQL_REPLICA_MATCHERS = [/\A\s*(select|with.+\)\s*select)\s/i].freeze
      SQL_ALL_MATCHERS = [/\A\s*set\s/i].freeze
      SQL_SKIP_ALL_MATCHERS = [/\A\s*set\s+local\s/i].freeze

      attr_reader :config

      def initialize(*args)
        args[0][:janus]['replica']['database'] = args[0][:database]
        args[0][:janus]['primary']['database'] = args[0][:database]

        @replica_config = args[0][:janus]['replica']
        args[0] = args[0][:janus]['primary']

        super(*args)
        @connection_parameters ||= args[0]
        update_config
      end

      def execute(sql)
        if should_send_to_all?(sql)
          send_to_replica(sql, connection: :all, method: :execute)
          return super(sql)
        end
        return send_to_replica(sql, connection: :replica, method: :execute) if can_go_to_replica?(sql)

        Janus::Context.stick_to_primary if write_query?(sql)
        Janus::Context.used_connection(:primary)

        super(sql)
      end

      def execute_and_free(sql, name = nil, async: false)
        if should_send_to_all?(sql)
          send_to_replica(sql, name, connection: :all)
          return super(sql, name, async:)
        end
        return send_to_replica(sql, connection: :replica) if can_go_to_replica?(sql)

        Janus::Context.stick_to_primary if write_query?(sql)
        Janus::Context.used_connection(:primary)

        super(sql, name, async:)
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
        %w(INSERT UPDATE DELETE LOCK CREATE GRANT).include?(sql.split(' ').first)
      end

      def update_config
        @config[:flags] ||= 0

        if @config[:flags].is_a? Array
          @config[:flags].push FOUND_ROWS
        else
          @config[:flags] |= ::Mysql2::Client::FOUND_ROWS
        end
      end
    end
  end
end
