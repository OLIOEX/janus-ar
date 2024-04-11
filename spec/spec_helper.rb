# frozen_string_literal: true

require 'pry'

require 'active_record'

require './lib/janus'
require './lib/active_record/connection_adapters/janus_mysql2_adapter'

class QueryLogger
  def initialize
    @_logs = []
  end

  def clear_logs
    @_logs = []
  end

  def log(message)
    @_logs << message
  end
end


ActiveRecord::LogSubscriber.logger = QueryLogger.new
