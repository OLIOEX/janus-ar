# frozen_string_literal: true

RSpec.describe ActiveRecord::ConnectionAdapters::JanusMysql2Adapter do
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
end
