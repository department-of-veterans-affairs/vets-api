# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EVSS::NewRequestDecision, type: :job do
  let(:client_stub) { instance_double('EVSS::Claims::Service') }
  let(:user) { create(:user, :loa3) }
  let(:evss_id) { 189_625 }

  it 'posts a waiver to EVSS' do
    expect(User).to receive(:find).with(user.uuid).and_return(user)
    allow(EVSS::Claims::Service).to receive(:new).with(user) { client_stub }
    expect(client_stub).to receive(:request_decision).with(evss_id)
    described_class.new.perform(user.uuid, evss_id)
  end
end
