# frozen_string_literal: true

RSpec.describe ActiveRecord::ConnectionAdapters::JanusTrilogyAdapter do
  subject { described_class.new(config) }

  let(:database) { 'test' }
  let(:primary_config) do
    {
      'username' => 'primary',
      'password' => 'primary_password',
      'host' => '127.0.0.1',
      'ssl' => true,
      'ssl_mode' => 'REQUIRED',
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
      'ssl_mode' => 'REQUIRED',
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
    # Trilogy enables FOUND_ROWS via the `found_rows` option (not mysql2-style
    # flags), and ActiveRecord's TrilogyAdapter forces it on. We assert it is
    # present even though the supplied config omits it.
    it 'creates primary connection as expected' do
      config = primary_config.dup.freeze
      expect(subject.config).to eq config.merge('database' => database, 'found_rows' => true).symbolize_keys
    end

    it 'creates replica connection as expected' do
      config = replica_config.dup.freeze
      expect(
        subject.replica_connection.instance_variable_get(:@config)
      ).to eq config.merge('database' => database, 'found_rows' => true).symbolize_keys
    end

    context 'Rails sets empty database for server connection' do
      let(:database) { nil }

      it 'creates primary connection as expected' do
        config = primary_config.dup.freeze
        expect(subject.config).to eq config.merge('database' => nil, 'found_rows' => true).symbolize_keys
      end

      it 'creates replica connection as expected' do
        config = replica_config.dup.freeze
        expect(
          subject.replica_connection.instance_variable_get(:@config)
        ).to eq config.merge('database' => nil, 'found_rows' => true).symbolize_keys
      end
    end
  end

  describe 'Integration tests' do
    let(:table_name) { 'table_name_trilogy' }

    it_behaves_like 'a mysql like server'
  end
end
