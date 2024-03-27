# frozen_string_literal: true

RSpec.describe Mysql2Split::Logging::Logger do
  describe '.log' do
    let(:logger) { double('logger') }

    before do
      described_class.logger = logger
    end

    it 'logs the message with the specified format' do
      expect(logger).to receive(:send).with(:info, '[Mysql2Split] Test message')
      described_class.log('Test message', :info)
    end

    it 'does not log the message if logger is not set' do
      described_class.logger = nil
      expect(logger).not_to receive(:send)
      described_class.log('Test message', :info)
    end
  end

  describe '.logger=' do
    let(:logger) { double('logger') }

    it 'sets the logger' do
      described_class.logger = logger
      expect(described_class.logger).to eq(logger)
    end
  end
end
