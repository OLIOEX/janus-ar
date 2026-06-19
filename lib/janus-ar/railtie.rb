# frozen_string_literal: true

require 'rails/railtie'

module Janus
  class Railtie < ::Rails::Railtie
    # Clear Janus' per-request primary stickiness at the start of every unit of
    # work wrapped by the Rails executor (web requests, ActiveJob and
    # Sidekiq-on-Rails jobs). Without this, a pooled thread that performs a
    # write keeps routing reads to the primary for the rest of its life.
    initializer 'janus.clear_context_per_execution' do |app|
      Janus::Context.install_reset_hook(app.executor)
    end
  end
end
