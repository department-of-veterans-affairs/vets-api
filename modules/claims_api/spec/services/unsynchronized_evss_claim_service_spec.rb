# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::UnsynchronizedEVSSClaimService, type: :model do
  let(:user) { create(:user, :loa3) }

  before do
    external_key = user.common_name || user.email
    allow(BGS::Services).to receive(:new).with({ external_uid: user.icn, external_key: })
    allow(Veteran::User).to receive(:new) { OpenStruct.new(power_of_attorney: PowerOfAttorney.new(code: 'A1Q')) }
    @veteran = Veteran::User.new(user)
    @veteran.power_of_attorney = PowerOfAttorney.new(code: 'A1Q')
  end

  it 'accesses a veteran' do
    service = ClaimsApi::UnsynchronizedEVSSClaimService.new user
    expect(service.veteran.power_of_attorney.code).to eq('A1Q')
  end

  it 'does not bomb out if power of attorney is called first' do
    service = ClaimsApi::UnsynchronizedEVSSClaimService.new user
    expect(service.power_of_attorney.code).to eq('A1Q')
  end
end
