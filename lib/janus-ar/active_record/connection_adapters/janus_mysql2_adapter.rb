# frozen_string_literal: true

require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/mysql2_adapter'
require_relative '../../../janus-ar'
require_relative '../../adapter_extensions'

module ActiveRecord
  module ConnectionHandling
    def janus_mysql2_connection(config)
      ActiveRecord::ConnectionAdapters::JanusMysql2Adapter.new(config)
    end
  end

  class Base
    def self.janus_mysql2_adapter_class
      ActiveRecord::ConnectionAdapters::JanusMysql2Adapter
    end
  end

  module ConnectionAdapters
    class JanusMysql2Adapter < ActiveRecord::ConnectionAdapters::Mysql2Adapter
      include Janus::AdapterExtensions

      private

      def replica_adapter_class
        ActiveRecord::ConnectionAdapters::Mysql2Adapter
      end
    end
  end
end
