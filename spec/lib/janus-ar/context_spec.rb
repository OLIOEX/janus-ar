# frozen_string_literal: true

require 'janus-ar/context'
require 'active_support/executor'

RSpec.describe Janus::Context do
  after(:each) { described_class.release_all }

  describe '#initialize' do
    it 'defaults to the replica and a primary last-used connection' do
      context = described_class.new
      expect(context.use_primary?).to be false
      expect(context.last_used_connection).to eq(:primary)
    end

    it 'can be created pinned to the primary' do
      expect(described_class.new(primary: true).use_primary?).to be true
    end
  end

  describe '#stick_to_primary' do
    it 'sets the primary flag to true' do
      context = described_class.new
      context.stick_to_primary
      expect(context.use_primary?).to be true
    end
  end

  describe '#release_all' do
    it 'resets the primary flag and the last used connection' do
      context = described_class.new(primary: true)
      context.used_connection(:primary)
      context.release_all
      expect(context.use_primary?).to be false
      expect(context.last_used_connection).to be_nil
    end
  end

  describe '#used_connection' do
    it 'sets the last used connection' do
      context = described_class.new
      context.used_connection(:replica)
      expect(context.last_used_connection).to eq(:replica)
    end
  end

  describe 'class-level access' do
    it 'sticks and releases the current execution state' do
      described_class.stick_to_primary
      expect(described_class.use_primary?).to be true
      described_class.release_all
      expect(described_class.use_primary?).to be false
    end

    it 'isolates state between threads' do
      described_class.stick_to_primary
      other = Thread.new { described_class.use_primary? }.value
      expect(other).to be false
      expect(described_class.use_primary?).to be true
    end
  end

  describe '.install_reset_hook' do
    let(:executor) { Class.new(ActiveSupport::Executor) }

    it 'releases the context at the start of every executor run' do
      described_class.install_reset_hook(executor)
      described_class.stick_to_primary

      stuck_inside = nil
      executor.wrap { stuck_inside = described_class.use_primary? }

      expect(stuck_inside).to be false
    end

    it 'stops stickiness leaking from a previous run into the next' do
      described_class.install_reset_hook(executor)

      executor.wrap { described_class.stick_to_primary }

      leaked = nil
      executor.wrap { leaked = described_class.use_primary? }
      expect(leaked).to be false
    end
  end
end
