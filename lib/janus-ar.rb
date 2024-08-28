# frozen_string_literal: true

require 'active_support'

module Janus
  autoload :Context, 'janus-ar/context'
  autoload :Client, 'janus-ar/client'
  autoload :QueryDirector, 'janus-ar/query_director'
  autoload :VERSION, 'janus-ar/version'
  autoload :DbConsoleConfig, 'janus-ar/db_console_config'

  module Logging
    autoload :Subscriber, 'janus-ar/logging/subscriber'
    autoload :Logger, 'janus-ar/logging/logger'
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
    subscriber.extend Janus::Logging::Subscriber
  end
end
