# frozen_string_literal: true
require 'rails_helper'

require 'evss/request_decision'
require 'evss/auth_headers'

RSpec.describe EVSS::RequestDecision, type: :job do
  let(:client_stub) { instance_double('EVSS::Claims::Service') }
  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:evss_id) { 189_625 }

  it 'posts a waiver to EVSS' do
    expect(User).to receive(:find).with(user.uuid).and_return(user)
    allow(EVSS::Claims::Service).to receive(:new).with(user) { client_stub }
    expect(client_stub).to receive(:request_decision).with(evss_id)
    described_class.new.perform(user.uuid, evss_id)
  end
end
