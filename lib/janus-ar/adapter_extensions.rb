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

      @replica_config = config[:janus]['replica'].symbolize_keys
      args[0] = config[:janus]['primary'].symbolize_keys

      super
      @connection_parameters ||= args[0]
    end

    # The argument lists below intentionally use anonymous splats and a bare
    # `super`: ActiveRecord's `raw_execute`/`execute` signatures differ between
    # versions, so we forward whatever we are given unchanged rather than
    # restating (and pinning ourselves to) the current signature.
    def raw_execute(sql, *, **)
      case where_to_send?(sql)
      when :all
        send_to_replica(sql, :all)
        super
      when :replica
        send_to_replica(sql, :replica)
      else
        mark_primary(sql)
        super
      end
    end

    def execute(sql, *, **)
      case where_to_send?(sql)
      when :all
        send_to_replica(sql, :all)
        super
      when :replica
        send_to_replica(sql, :replica)
      else
        mark_primary(sql)
        super
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
      @replica_connection ||= replica_adapter_class.new(@replica_config)
    end

    private

    def mark_primary(sql)
      Janus::Context.stick_to_primary if write_query?(sql)
      Janus::Context.used_connection(:primary)
    end

    def where_to_send?(sql)
      Janus::QueryDirector.new(sql, open_transactions).where_to_send?
    end

    def send_to_replica(sql, connection)
      Janus::Context.used_connection(connection)
      replica_connection.execute(sql)
    end
  end
end
