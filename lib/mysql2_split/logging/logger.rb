# frozen_string_literal: true

module Mysql2Split
  module Logging
    class Logger
      class << self
        def log(message, format = :info)
          logger&.send(format, "[Mysql2Split] #{message}")
        end

        attr_accessor :logger
      end
    end
  end
end
