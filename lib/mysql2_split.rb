# frozen_string_literal: true

require 'active_support'

module Mysql2Split
  autoload :Context, 'mysql2_split/context'
  autoload :VERSION, 'mysql2_split/version'

  module Logging
    autoload :Subscriber, 'mysql2_split/logging/subscriber'
    autoload :Logger, 'mysql2_split/logging/logger'
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::LogSubscriber.log_subscribers.each do |subscriber|
    subscriber.extend Mysql2Split::Logging::Subscriber
  end
end
