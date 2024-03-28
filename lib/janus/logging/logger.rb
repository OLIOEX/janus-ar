# frozen_string_literal: true

module Janus
  module Logging
    class Logger
      class << self
        def log(message, format = :info)
          logger&.send(format, "[Janus] #{message}")
        end

        attr_accessor :logger
      end
    end
  end
end
