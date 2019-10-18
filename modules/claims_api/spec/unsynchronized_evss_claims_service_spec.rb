# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/unsynchronized_evss_claims_service'

RSpec.describe ClaimsApi::UnsynchronizedEVSSClaimService, type: :model do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

  before do
    @client_stub = instance_double('EVSS::VsoSearch::Service')
    allow(EVSS::VsoSearch::Service).to receive(:new).with(user) { @client_stub }
    allow(@client_stub).to receive(:get_current_info) { get_fixture('json/veteran_with_poa') }
    @veteran = Veteran::User.new(user)
    @veteran.power_of_attorney = PowerOfAttorney.new(ssn: '123456789')
  end

  it 'accesses a veteran' do
    service = ClaimsApi::UnsynchronizedEVSSClaimService.new user
    expect(service.veteran.veteran_name).to eq('JEFF TERRELL WATSON')
    expect(service.veteran.power_of_attorney.code).to eq('A1Q')
  end

  it 'does not bomb out if power of attorney is called first' do
    service = ClaimsApi::UnsynchronizedEVSSClaimService.new user
    expect(service.power_of_attorney.code).to eq('A1Q')
    expect(service.veteran.veteran_name).to eq('JEFF TERRELL WATSON')
  end
end
