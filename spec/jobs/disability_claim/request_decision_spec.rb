# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

RSpec.describe DisabilityClaim::RequestDecision, type: :job do
  let(:client_stub) { instance_double('EVSS::ClaimsService') }
  let(:user) { FactoryGirl.create(:mvi_user) }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:claim) do
    FactoryGirl.create(:disability_claim, id: 1, evss_id: 189_625,
                                          user_uuid: user.uuid)
  end

  it 'posts a waiver to EVSS' do
    allow(EVSS::ClaimsService).to receive(:new) { client_stub }
    expect(client_stub).to receive(:submit_5103_waiver).with(claim.evss_id)
    described_class.new.perform(auth_headers, claim.evss_id)
  end
end
