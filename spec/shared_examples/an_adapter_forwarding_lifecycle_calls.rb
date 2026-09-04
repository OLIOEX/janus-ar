# frozen_string_literal: true

RSpec.shared_examples 'an adapter forwarding lifecycle calls' do
  let(:replica_connection) { instance_double(replica_adapter_class) }

  before do
    allow(subject).to receive(:replica_connection).and_return(replica_connection)
  end

  it 'forwards discard! to the replica connection' do
    allow(replica_connection).to receive(:discard!)

    subject.discard!

    expect(replica_connection).to have_received(:discard!)
  end
end
