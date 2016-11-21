# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

RSpec.describe DisabilityClaim::RequestDecision, type: :job do
  let(:client_stub) { instance_double('EVSS::ClaimsService') }
  let(:user) { FactoryGirl.build(:loa3_user) }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:evss_id) { 189_625 }

  it 'posts a waiver to EVSS' do
    allow(EVSS::ClaimsService).to receive(:new) { client_stub }
    expect(client_stub).to receive(:request_decision).with(evss_id)
    described_class.new.perform(auth_headers, evss_id)
  end
end
