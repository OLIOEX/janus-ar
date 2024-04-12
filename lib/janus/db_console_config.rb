# frozen_string_literal: true

module Janus
  class DbConsoleConfig
    def initialize(config)
      @_config = config.configuration_hash
    end

    def configuration_hash
      @_config[:janus]['replica'].symbolize_keys
    end

    def database
      @_config[:database]
    end
  end
end
