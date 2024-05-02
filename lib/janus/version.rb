# frozen_string_literal: true

module Janus
  unless defined?(::Janus::VERSION)
    module VERSION
      MAJOR = 0
      MINOR = 15
      PATCH = 2
      PRE = nil

      def self.to_s
        [MAJOR, MINOR, PATCH, PRE].compact.join('.')
      end
    end
  end
  ::Janus::VERSION
end
