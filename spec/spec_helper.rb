# frozen_string_literal: true

require 'pry'

require 'active_record'

require './lib/janus'
require './lib/active_record/connection_adapters/janus_mysql2_adapter'
require './lib/active_record/connection_adapters/janus_trilogy_adapter'

require './spec/shared_examples/a_mysql_like_server.rb'

class QueryLogger
  def initialize
    @_logs = []
  end

  def flush_all
    @_logs = []
  end

  def log(level, message)
    @_logs << "#{level}: #{message}"
  end

  def error(message)
    log('error', message)
  end

  def queries
    @_logs
  end

  def debug?
    true
  end

  def debug(message)
    log('debug', message)
  end
end

$query_logger = ActiveRecord::Base.logger = QueryLogger.new
