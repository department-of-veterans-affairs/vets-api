# frozen_string_literal: true

require 'rails_helper'
require 'bgs/power_of_attorney_verifier.rb'

describe BGS::PowerOfAttorneyVerifier do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:identity) { FactoryBot.create(:user_identity) }

  before do
    @client_stub = instance_double('BGS::Services')
    external_key = user.common_name || user.email
    allow(BGS::Services).to receive(:new).with({ external_uid: user.icn, external_key: external_key })
    allow(@client_stub).to receive(:claimant).and_return(nil)
    allow(@client_stub.claimant).to receive(:find_poa_by_participant_id) { get_fixture('json/bgs_with_poa') }
    @veteran = Veteran::User.new(user)
    @veteran.power_of_attorney = PowerOfAttorney.new(ssn: '123456789')
  end

  it 'does not raise an exception if poa matches' do
    FactoryBot.create(
      :representative,
      poa_codes: ['A1Q'],
      first_name: identity.first_name,
      last_name: identity.last_name
    )
    expect do
      BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.not_to raise_error
  end

  it 'raises an exception if poa does not matches' do
    FactoryBot.create(
      :representative,
      poa_codes: ['B1Q'],
      first_name: identity.first_name,
      last_name: identity.last_name
    )
    expect do
      BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.to raise_error(Common::Exceptions::Unauthorized)
  end

  it 'raises an exception if representative not found' do
    expect do
      BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.to raise_error(Common::Exceptions::Unauthorized)
  end
end
