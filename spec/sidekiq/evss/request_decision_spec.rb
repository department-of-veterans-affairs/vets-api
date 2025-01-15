# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EVSS::RequestDecision, type: :job do
  let(:client_stub) { instance_double(EVSS::ClaimsService) }
  let(:user) { build(:user, :loa3) }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:evss_id) { 189_625 }

  it 'posts a waiver to EVSS' do
    allow(EVSS::ClaimsService).to receive(:new) { client_stub }
    expect(client_stub).to receive(:request_decision).with(evss_id)
    described_class.new.perform(auth_headers, evss_id)
  end
end

RSpec.describe EVSSClaim::RequestDecision, type: :job do
  it 're-queues the job into the new namespace' do
    expect { described_class.new.perform(nil, nil) }
      .to change { EVSS::RequestDecision.jobs.size }
      .from(0)
      .to(1)
  end
end
