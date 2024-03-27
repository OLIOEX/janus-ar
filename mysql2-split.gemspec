# frozen_string_literal: true

require File.expand_path('lib/mysql2_split/version.rb', __dir__)

Gem::Specification.new do |gem|
  gem.authors       = ['Lloyd Watkin']
  gem.email         = ['lloyd@olioex.com']
  gem.description   = 'Read/Write proxy for ActiveRecord using primary/replca databases'
  gem.summary       = 'Read/Write proxy for ActiveRecord using primary/replca databases'
  gem.homepage      = 'https://github.com/olioex/mysql2-split'
  gem.licenses      = ['MIT']
  gem.metadata      = {
    'source_code_uri' => 'https://github.com/olioex/mysql2-split'
  }

  gem.files         = `git ls-files`.split($OUTPUT_RECORD_SEPARATOR)
  gem.executables   = gem.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  gem.name          = 'mysql2-split'
  gem.require_paths = ['lib']
  gem.version       = Mysql2Split::VERSION

  gem.required_ruby_version = '>= 3.2.0'

  gem.add_dependency 'forwardable', '~> 1'

  gem.add_development_dependency 'activerecord', '>= 7.1.0'
  gem.add_development_dependency 'activesupport', '>= 7.1.0'
  gem.add_development_dependency 'mysql2'
  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec', '~> 3'
  gem.add_development_dependency 'rubocop', '~> 1.62.0'
  gem.add_development_dependency 'rubocop-rails', '~> 2.24.0'
end
