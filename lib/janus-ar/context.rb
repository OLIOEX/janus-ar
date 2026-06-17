# frozen_string_literal: true

require 'active_support/isolated_execution_state'

module Janus
  # Per-execution state that records whether the current unit of work has been
  # pinned to the primary (e.g. after a write, so subsequent reads stay
  # consistent). State is stored in ActiveSupport::IsolatedExecutionState so it
  # follows the application's configured isolation level (thread or fiber),
  # matching ActiveRecord itself.
  #
  # Because pooled threads/fibers are reused across requests and jobs, the
  # context MUST be released between units of work or a thread that performed a
  # single write would keep routing every later read to the primary. The Rails
  # integration (see Janus::Railtie) does this automatically; outside Rails,
  # call Janus::Context.release_all yourself (e.g. in a Sidekiq middleware).
  class Context
    STATE_KEY = :janus_ar_context

    def initialize(primary: false)
      @primary = primary
      @last_used_connection = :primary
    end

    def stick_to_primary
      @primary = true
    end

    def release_all
      @primary = false
      @last_used_connection = nil
    end

    def use_primary?
      @primary
    end

    def used_connection(connection)
      @last_used_connection = connection
    end

    attr_reader :last_used_connection

    class << self
      def stick_to_primary
        current.stick_to_primary
      end

      def release_all
        current.release_all
      end

      def used_connection(connection)
        current.used_connection(connection)
      end

      def use_primary?
        current.use_primary?
      end

      def last_used_connection
        current.last_used_connection
      end

      # Release the context at the start of every unit of work wrapped by the
      # given ActiveSupport executor (web requests, ActiveJob and
      # Sidekiq-on-Rails jobs all run inside it).
      def install_reset_hook(executor)
        executor.to_run { Janus::Context.release_all }
      end

      protected

      def current
        ActiveSupport::IsolatedExecutionState[STATE_KEY] ||= new
      end
    end
  end
end
