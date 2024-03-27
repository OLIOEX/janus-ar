# frozen_string_literal: true

module Mysql2Split
  class Context
    THREAD_KEY = :mysql2_split_context

    # Stores the staged data with an expiration time based on the current time,
    # and clears any expired entries. Returns true if any changes were made to
    # the current store
    def initialize(primary: false, expiry: nil)
      @primary = primary
      @expiry = expiry
      @last_used_connection = :primary
    end

    def stick_to_primary
      @primary = true
    end

    def potential_write
      stick_to_primary
    end

    def release_all
      @primary = false
      @expiry = nil
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

      protected

      def current
        fetch(THREAD_KEY) { new }
      end

      def fetch(key)
        get(key) || set(key, yield)
      end

      def get(key)
        Thread.current.thread_variable_get(key)
      end

      def set(key, value)
        Thread.current.thread_variable_set(key, value)
      end
    end
  end
end
