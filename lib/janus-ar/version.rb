# frozen_string_literal: true

module Janus
  unless defined?(::Janus::VERSION)
    module VERSION
      MAJOR = 7
      MINOR = 2
      PATCH = 1
      PRE = nil

      def self.to_s
        [MAJOR, MINOR, PATCH, PRE].compact.join('.')
      end
    end
  end
  ::Janus::VERSION
end
