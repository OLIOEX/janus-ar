# frozen_string_literal: true

require 'janus/context'

RSpec.describe Janus::Context do
  describe '#initialize' do
    it 'sets the primary flag and expiry' do
      context = described_class.new(primary: true, expiry: 60)
      expect(context.use_primary?).to be true
      expect(context.last_used_connection).to eq(:primary)
    end
  end

  describe '#stick_to_primary' do
    it 'sets the primary flag to true' do
      context = described_class.new
      context.stick_to_primary
      expect(context.use_primary?).to be true
    end
  end

  describe '#potential_write' do
    it 'calls stick_to_primary' do
      context = described_class.new
      expect(context).to receive(:stick_to_primary)
      context.potential_write
    end
  end

  describe '#release_all' do
    it 'resets the primary flag and expiry' do
      context = described_class.new(primary: true, expiry: 60)
      context.release_all
      expect(context.use_primary?).to be false
      expect(context.last_used_connection).to be_nil
    end
  end

  describe '#used_connection' do
    it 'sets the last used connection' do
      context = described_class.new
      context.used_connection(:secondary)
      expect(context.last_used_connection).to eq(:secondary)
    end
  end
end
