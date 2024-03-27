# frozen_string_literal: true

module Mysql2Split
  module Logging
    module Subscriber
      IGNORE_PAYLOAD_NAMES = %w[SCHEMA EXPLAIN].freeze

      def sql(event)
        name = event.payload[:name]
        unless IGNORE_PAYLOAD_NAMES.include?(name)
          name = [current_wrapper_name(event), name].compact.join(' ')
          event.payload[:name] = name
        end
        super(event)
      end

      protected

      def current_wrapper_name(_event)
        connection = Mysql2Split::Context.last_used_connection
        return nil unless connection

        "[#{connection}]"
      end
    end
  end
end
