# frozen_string_literal: true

require 'janus-ar/db_console_config'

RSpec.describe Janus::DbConsoleConfig do
  subject(:console_config) { described_class.new(db_config) }

  let(:db_config) do
    instance_double(
      ActiveRecord::DatabaseConfigurations::HashConfig,
      configuration_hash: {
        database: 'my_database',
        janus: {
          'primary' => { 'host' => 'primary.local', 'username' => 'primary' },
          'replica' => { 'host' => 'replica.local', 'username' => 'replica' },
        },
      }
    )
  end

  it 'exposes the replica configuration with symbol keys so dbconsole connects to a replica' do
    expect(console_config.configuration_hash).to eq(host: 'replica.local', username: 'replica')
  end

  it 'exposes the database name from the top-level config' do
    expect(console_config.database).to eq('my_database')
  end
end
