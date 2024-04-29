# frozen_string_literal: true

RSpec.describe ActiveRecord::ConnectionAdapters::JanusTrilogyAdapter do
  subject { described_class.new(config) }

  it { expect(described_class::FOUND_ROWS).to eq 'FOUND_ROWS' }
  it { expect(described_class::SQL_SKIP_ALL_MATCHERS).to eq [/\A\s*set\s+local\s/i] }
  it {
    expect(described_class::SQL_PRIMARY_MATCHERS).to eq(
      [
        /\A\s*select.+for update\Z/i, /select.+lock in share mode\Z/i,
        /\A\s*select.+(nextval|currval|lastval|get_lock|release_lock|pg_advisory_lock|pg_advisory_unlock)\(/i,
        /\A\s*show/i
      ]
    )
  }
  it { expect(described_class::SQL_REPLICA_MATCHERS).to eq([/\A\s*(select|with.+\)\s*select)\s/i]) }
  it { expect(described_class::SQL_ALL_MATCHERS).to eq([/\A\s*set\s/i]) }
  it {
    expect(described_class::WRITE_PREFIXES).to eq %w(INSERT UPDATE DELETE LOCK CREATE GRANT DROP ALTER TRUNCATE FLUSH)
  }

  let(:database) { 'test' }
  let(:primary_config) do
    {
      'username' => 'primary',
      'password' => 'primary_password',
      'host' => '127.0.0.1',
      'ssl' => true,
      'ssl_mode' => Trilogy::SSL_PREFERRED_NOVERIFY,
      'tls_min_version' => Trilogy::TLS_VERSION_12,
    }
  end
  let(:replica_config) do
    {
      'username' => 'replica',
      'password' => 'replica_password',
      'host' => '127.0.0.1',
      'pool' => 500,
      'ssl' => true,
      'ssl_mode' => Trilogy::SSL_PREFERRED_NOVERIFY,
      'tls_min_version' => Trilogy::TLS_VERSION_12,
    }
  end
  let(:config) do
    {
      database:,
      adapter: 'janus_trilogy',
      janus: {
        'primary' => primary_config,
        'replica' => replica_config,
      },
    }
  end

  describe 'Configuration' do
    it 'creates primary connection as expected' do
      config = primary_config.dup.freeze
      expect(subject.config).to eq config.merge('database' => database,
                                                'flags' => ::Janus::Client::FOUND_ROWS).symbolize_keys
    end

    it 'creates replica connection as expected' do
      config = replica_config.dup.freeze
      expect(
        subject.replica_connection.instance_variable_get(:@config)
      ).to eq config.merge('database' => database).symbolize_keys
    end

    context 'Rails sets empty database for server connection' do
      let(:database) { nil }

      it 'creates primary connection as expected' do
        config = primary_config.dup.freeze
        expect(subject.config).to eq config.merge(
          'database' => nil,
          'flags' => ::Janus::Client::FOUND_ROWS
        ).symbolize_keys
      end

      it 'creates replica connection as expected' do
        config = replica_config.dup.freeze
        expect(
          subject.replica_connection.instance_variable_get(:@config)
        ).to eq config.merge('database' => nil).symbolize_keys
      end
    end
  end

  describe 'Integration tests' do
    let(:table_name) { 'table_name_trilogy' }

    it_behaves_like 'a mysql like server'
  end
end
