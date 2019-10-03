# frozen_string_literal: true

require 'rails_helper'
require 'evss/power_of_attorney_verifier.rb'

describe EVSS::PowerOfAttorneyVerifier do
  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }
  let(:identity) { FactoryBot.create(:user_identity) }

  before do
    @client_stub = instance_double('EVSS::VsoSearch::Service')
    allow(EVSS::VsoSearch::Service).to receive(:new).with(user) { @client_stub }
    allow(@client_stub).to receive(:get_current_info) { get_fixture('json/veteran_with_poa') }
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
      EVSS::PowerOfAttorneyVerifier.new(user).verify(identity)
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
      EVSS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.to raise_error(Common::Exceptions::Unauthorized)
  end

  it 'raises an exception if representitive not found' do
    expect do
      EVSS::PowerOfAttorneyVerifier.new(user).verify(identity)
    end.to raise_error(Common::Exceptions::Unauthorized)
  end
end
