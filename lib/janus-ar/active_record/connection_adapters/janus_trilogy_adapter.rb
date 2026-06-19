# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/trilogy_adapter'
require_relative '../../../janus-ar'
require_relative '../../adapter_extensions'

module ActiveRecord
  module ConnectionHandling
    def janus_trilogy_connection(config)
      ActiveRecord::ConnectionAdapters::JanusTrilogyAdapter.new(config)
    end
  end

  class Base
    def self.janus_trilogy_adapter_class
      ActiveRecord::ConnectionAdapters::JanusTrilogyAdapter
    end
  end

  module ConnectionAdapters
    class JanusTrilogyAdapter < ActiveRecord::ConnectionAdapters::TrilogyAdapter
      include Janus::AdapterExtensions

      private

      def replica_adapter_class
        ActiveRecord::ConnectionAdapters::TrilogyAdapter
      end
    end
  end
end
