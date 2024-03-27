# frozen_string_literal: true

module Mysql2Split
  unless defined?(::Mysql2Split::VERSION)
    module VERSION
      MAJOR = 0
      MINOR = 1
      PATCH = 0
      PRE = nil

      def self.to_s
        [MAJOR, MINOR, PATCH, PRE].compact.join('.')
      end
    end
  end
  ::Mysql2Split::VERSION
end
