# frozen_string_literal: true

require 'janus/client'

RSpec.describe Janus::Client do
  it { expect(described_class::FOUND_ROWS).to eq 2 }
end
