# frozen_string_literal: true

# ActiveRecord's ForkTracker calls `discard!` on every adapter in a forked
# child so the child never closes a socket the parent is still using. Janus
# owns a second (replica) connection, so it has to pass that on.
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
