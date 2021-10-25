# frozen_string_literal: true

require 'rails_helper'
require 'bgs/power_of_attorney_verifier'

describe BGS::PowerOfAttorneyVerifier do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:identity) { FactoryBot.create(:user_identity) }

  before do
    external_key = user.common_name || user.email
    allow(BGS::Services).to receive(:new).with({ external_uid: user.icn, external_key: external_key })
    allow(Veteran::User).to receive(:new) { OpenStruct.new(power_of_attorney: PowerOfAttorney.new(code: 'A1Q')) }
    @veteran = Veteran::User.new(user)
    @veteran.power_of_attorney = PowerOfAttorney.new(code: 'A1Q')
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

  context 'when multiple representatives have the same name' do
    it 'raises an exception if poa matches' do
      FactoryBot.create(
        :representative,
        representative_id: '1234',
        poa_codes: ['A1Q'],
        first_name: identity.first_name,
        last_name: identity.last_name
      )
      FactoryBot.create(
        :representative,
        representative_id: '5678',
        poa_codes: ['B1Q'],
        first_name: identity.first_name,
        last_name: identity.last_name
      )
      expect do
        BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
      end.to raise_error(Common::Exceptions::Unauthorized)
    end

    it 'raises an exception if poa does not matches' do
      FactoryBot.create(
        :representative,
        representative_id: '1234',
        poa_codes: ['A1Q'],
        first_name: identity.first_name,
        last_name: identity.last_name
      )
      FactoryBot.create(
        :representative,
        representative_id: '5678',
        poa_codes: ['A1Q'],
        first_name: identity.first_name,
        last_name: identity.last_name
      )
      expect do
        BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
      end.to raise_error(Common::Exceptions::Unauthorized)
    end
  end

  it 'raises an exception if representative not found' do
    expect do
      BGS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.to raise_error(Common::Exceptions::Unauthorized)
  end
end
