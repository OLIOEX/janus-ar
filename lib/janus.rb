# frozen_string_literal: true

require 'active_support'

module Janus
  autoload :Context, 'janus/context'
  autoload :VERSION, 'janus/version'
  autoload :DbConsoleConfig, 'janus/db_console_config'

  module Logging
    autoload :Subscriber, 'janus/logging/subscriber'
    autoload :Logger, 'janus/logging/logger'
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
    subscriber.extend Janus::Logging::Subscriber
  end
end
