# frozen_string_literal: true

require File.expand_path('lib/janus-ar/version.rb', __dir__)

Gem::Specification.new do |gem|
  gem.authors       = ['Lloyd Watkin']
  gem.email         = ['lloyd@olioex.com']
  gem.description   = 'Read/Write proxy for ActiveRecord using primary/replica databases'
  gem.summary       = 'Read/Write proxy for ActiveRecord using primary/replica databases'
  gem.homepage      = 'https://github.com/olioex/janus-ar'
  gem.licenses      = %w(MIT)
  gem.metadata      = {
    'source_code_uri' => 'https://github.com/olioex/janus-ar',
  }

  gem.files         = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.name          = 'janus-ar'
  gem.require_paths = %w(lib)
  gem.version       = Janus::VERSION

  gem.required_ruby_version = '>= 3.2.0'

  gem.add_dependency 'activerecord', '>= 8.0', '< 9.0'
  gem.add_development_dependency 'activesupport', '>= 8.0'
  gem.add_development_dependency 'mysql2'
  gem.add_development_dependency 'trilogy'
  gem.add_development_dependency 'pry'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '~> 3'
  gem.add_development_dependency 'rubocop', '~> 1.80.0'
  gem.add_development_dependency 'rubocop-rails', '~> 2.33.3'
  gem.add_development_dependency 'rubocop-rspec'
  gem.add_development_dependency 'rubocop-thread_safety'
  gem.add_development_dependency 'rubocop-performance'
end
