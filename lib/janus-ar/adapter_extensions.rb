# frozen_string_literal: true

module Janus
  # Behaviour shared by the Janus MySQL2 and Trilogy adapters.
  #
  # Each Janus adapter subclasses the matching ActiveRecord adapter and owns the
  # *primary* connection (reached via `super`). This module routes every
  # statement to the primary, a lazily created replica connection, or both, and
  # keeps Janus::Context up to date.
  #
  # Including adapters only need to implement #replica_adapter_class.
  module AdapterExtensions
    # Connection-level errors that trigger a fall back to the primary when
    # `replica_failover` is enabled. Query errors (bad SQL etc.) are not
    # included on purpose: they would fail against the primary too, so failing
    # over would only hide the real problem.
    REPLICA_FAILOVER_ERRORS = [
      ActiveRecord::ConnectionNotEstablished,
      ActiveRecord::ConnectionFailed,
    ].freeze

    # Internal marker returned by #send_to_replica when a read could not reach
    # the replica and should be retried on the primary.
    FAILOVER = Object.new
    private_constant :FAILOVER

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def dbconsole(config, options = {})
        super(Janus::DbConsoleConfig.new(config), options)
      end
    end

    attr_reader :config

    def initialize(*args)
      config = args[0]
      config[:janus]['replica']['database'] = config[:database]
      config[:janus]['primary']['database'] = config[:database]

      @replica_failover = config[:janus].fetch('replica_failover', false)
      @replica_config = config[:janus]['replica'].symbolize_keys
      args[0] = config[:janus]['primary'].symbolize_keys

      super
      @connection_parameters ||= args[0]
    end

    # The argument lists below intentionally use anonymous splats and a bare
    # `super`: ActiveRecord's `raw_execute`/`execute` signatures differ between
    # versions, so we forward whatever we are given unchanged rather than
    # restating (and pinning ourselves to) the current signature. The block
    # given to #route runs the statement on the primary.
    def raw_execute(sql, *, **)
      route(sql) { super }
    end

    def execute(sql, *, **)
      route(sql) { super }
    end

    def connect!(...)
      guard_replica { replica_connection.connect!(...) }
      super
    end

    def reconnect!(...)
      guard_replica { replica_connection.reconnect!(...) }
      super
    end

    def disconnect!(...)
      guard_replica { replica_connection.disconnect!(...) }
      super
    end

    def clear_cache!(...)
      guard_replica { replica_connection.clear_cache!(...) }
      super
    end

    def replica_connection
      @replica_connection ||= replica_adapter_class.new(@replica_config)
    end

    private

    def route(sql)
      case where_to_send?(sql)
      when :all
        send_to_replica(sql, :all)
      when :replica
        result = send_to_replica(sql, :replica)
        return result unless result.equal?(FAILOVER)

        mark_primary(sql)
      else
        mark_primary(sql)
      end

      yield
    end

    def mark_primary(sql)
      Janus::Context.stick_to_primary if write_query?(sql)
      Janus::Context.used_connection(:primary)
    end

    def where_to_send?(sql)
      Janus::QueryDirector.new(sql, open_transactions).where_to_send?
    end

    def send_to_replica(sql, connection)
      guard_replica(FAILOVER) do
        Janus::Context.used_connection(connection)
        replica_connection.execute(sql)
      end
    end

    # Runs a replica operation. When `replica_failover` is enabled, a replica
    # connection error is logged and `failover_result` is returned instead of
    # raising, so the caller can fall back to the primary. Otherwise the error
    # propagates unchanged.
    def guard_replica(failover_result = nil)
      yield
    rescue *REPLICA_FAILOVER_ERRORS => e
      raise unless @replica_failover

      Janus::Logging::Logger.log("replica unavailable, falling back to primary (#{e.class}: #{e.message})", :warn)
      failover_result
    end
  end
end
