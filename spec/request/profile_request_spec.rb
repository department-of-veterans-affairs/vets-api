# frozen_string_literal: true
require 'rails_helper'
require 'backend_services'

RSpec.describe 'Fetching profile data', type: :request do
  let(:token) { 'abracadabra-open-sesame' }

  context 'when an LOA 3 user is logged in' do
    let(:mvi_user) { build :mvi_user }

    before do
      Session.create(uuid: mvi_user.uuid, token: token)
      User.create(mvi_user)
      allow_any_instance_of(User).to receive(:mvi).and_return(
        status: 'OK',
        birth_date: '18090212',
        edipi: '1234^NI^200DOD^USDOD^A',
        vba_corp_id: '12345678^PI^200CORP^USVBA^A',
        family_name: 'Lincoln',
        gender: 'M',
        given_names: %w(Abraham),
        icn: '1000123456V123456^NI^200M^USVHA^P',
        mhv_ids: ['123456^PI^200MH^USVHA^A'],
        ssn: '272111863',
        active_status: 'active'
      )

      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_user_url, nil, auth_header
    end

    it 'GET /v0/user - returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('profile')
    end

    it 'gives me the list of available services' do
      expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
        [
          BackendServices::FACILITIES,
          BackendServices::HCA,
          BackendServices::EDUCATION_BENEFITS,
          BackendServices::DISABILITY_BENEFITS,
          BackendServices::USER_PROFILE,
          BackendServices::RX,
          BackendServices::MESSAGING
        ].sort
      )
    end
  end

  context 'when an LOA 1 user is logged in' do
    let(:loa1_user) { build :loa1_user }

    before do
      Session.create(uuid: loa1_user.uuid, token: token)
      User.create(loa1_user)

      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_user_url, nil, auth_header
    end

    it 'GET /v0/user - returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('profile')
    end

    it 'gives me the list of available services' do
      expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
        [
          BackendServices::FACILITIES,
          BackendServices::HCA,
          BackendServices::EDUCATION_BENEFITS,
          BackendServices::USER_PROFILE
        ].sort
      )
    end
  end
end
