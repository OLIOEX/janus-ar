# frozen_string_literal: true

require 'janus-ar/context'
require 'janus-ar/logging/subscriber'

RSpec.describe Janus::Logging::Subscriber do
  # A minimal stand-in for ActiveRecord::LogSubscriber: it records the event it
  # is given so we can assert on the (possibly rewritten) payload name.
  let(:base_class) do
    Class.new do
      attr_reader :received_event

      def sql(event)
        @received_event = event
      end
    end
  end
  let(:subscriber) { base_class.new.extend(described_class) }
  let(:event) { instance_double(ActiveSupport::Notifications::Event, payload: { name: 'User Load' }) }

  after(:each) { Janus::Context.release_all }

  it 'tags the log name with the last used connection' do
    Janus::Context.used_connection(:replica)

    subscriber.sql(event)

    expect(event.payload[:name]).to eq('[replica] User Load')
    expect(subscriber.received_event).to eq(event)
  end

  it 'reflects the primary connection' do
    Janus::Context.used_connection(:primary)

    subscriber.sql(event)

    expect(event.payload[:name]).to eq('[primary] User Load')
  end

  it 'leaves the name unchanged when no connection has been used yet' do
    Janus::Context.release_all

    subscriber.sql(event)

    expect(event.payload[:name]).to eq('User Load')
  end

  Janus::Logging::Subscriber::IGNORE_PAYLOAD_NAMES.each do |ignored|
    it "does not tag #{ignored} statements" do
      Janus::Context.used_connection(:replica)
      ignored_event = instance_double(ActiveSupport::Notifications::Event, payload: { name: ignored })

      subscriber.sql(ignored_event)

      expect(ignored_event.payload[:name]).to eq(ignored)
    end
  end
end
