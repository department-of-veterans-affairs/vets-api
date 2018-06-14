# frozen_string_literal: true

require 'rails_helper'
require 'backend_services'

RSpec.describe 'user', type: :request do
  include SchemaMatchers

  let(:token) { 'abracadabra-open-sesame' }

  describe '/users' do
    context 'when an LOA 3 user is logged in' do
      let(:mhv_user) { build(:user, :mhv) }

      before do
        Session.create(uuid: mhv_user.uuid, token: token)
        allow_any_instance_of(MhvAccountTypeService).to receive(:mhv_account_type).and_return('Premium')
        mhv_account = double('MhvAccount', account_state: 'upgraded')
        allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
        allow(mhv_account).to receive(:terms_and_conditions_accepted?).and_return(true)
        allow(mhv_account).to receive(:needs_terms_acceptance?).and_return(false)
        User.create(mhv_user)
        auth_header = { 'Authorization' => "Token token=#{token}" }
        get v0_user_url, nil, auth_header
      end

      it 'GET /v0/user - returns proper json' do
        assert_response :success
        expect(response).to match_response_schema('user_loa3')
      end

      it 'gives me the list of available services' do
        expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
          [
            BackendServices::FACILITIES,
            BackendServices::HCA,
            BackendServices::EDUCATION_BENEFITS,
            BackendServices::EVSS_CLAIMS,
            BackendServices::USER_PROFILE,
            BackendServices::RX,
            BackendServices::MESSAGING,
            BackendServices::HEALTH_RECORDS,
            BackendServices::MHV_AC,
            BackendServices::FORM_PREFILL,
            BackendServices::SAVE_IN_PROGRESS,
            BackendServices::APPEALS_STATUS,
            BackendServices::IDENTITY_PROOFED
          ].sort
        )
      end

      it 'gives me the list of available prefill forms' do
        num_enabled = 2
        num_enabled += FormProfile::EDU_FORMS.length if Settings.edu.prefill
        num_enabled += FormProfile::HCA_FORMS.length if Settings.hca.prefill
        num_enabled += FormProfile::PENSION_BURIAL_FORMS.length if Settings.pension_burial.prefill
        num_enabled += FormProfile::VIC_FORMS.length if Settings.vic.prefill
        num_enabled += FormProfile::EVSS_FORMS.length if Settings.evss.prefill

        expect(JSON.parse(response.body)['data']['attributes']['prefills_available'].length).to be(num_enabled)
      end
    end

    context 'when an LOA 1 user is logged in', :skip_mvi do
      let(:loa1_user) { build(:user, :loa1) }

      before do
        Session.create(uuid: loa1_user.uuid, token: token)
        User.create(loa1_user)

        auth_header = { 'Authorization' => "Token token=#{token}" }
        get v0_user_url, nil, auth_header
      end

      it 'GET /v0/user - returns proper json' do
        assert_response :success
        expect(response).to match_response_schema('user_loa1')
      end

      it 'gives me the list of available services' do
        expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
          [
            BackendServices::FACILITIES,
            BackendServices::HCA,
            BackendServices::EDUCATION_BENEFITS,
            BackendServices::USER_PROFILE,
            BackendServices::SAVE_IN_PROGRESS,
            BackendServices::FORM_PREFILL
          ].sort
        )
      end
    end
  end

  describe 'authorized/:service/:action' do
    let(:token) { 'fa0f28d6-224a-4015-a3b0-81e77de269f2' }
    let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }

    before do
      Session.create(uuid: user.uuid, token: token)
      User.create(user)
      Settings.evss.mock_letters = false
    end

    context 'with an authorized evss user' do
      let(:user) { build(:user, :loa3) }

      it 'returns is_authorized true with no messages' do
        get '/v0/user/authorized/evss/access', nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to include_json(
          data: {
            id: '',
            type: 'service_auth_details',
            attributes: {
              policy: 'evss',
              policy_action: 'access?',
              is_authorized: true,
              errors: {}
            }
          }
        )
      end
    end

    context 'with an authorized evss user' do
      let(:user) { build(:unauthorized_evss_user, :loa3) }

      it 'returns is_authorized true with no messages' do
        get '/v0/user/authorized/evss/access', nil, auth_header
        expect(response).to have_http_status(:ok)
        expect(response.body).to include_json(
          data: {
            id: '',
            type: 'service_auth_details',
            attributes: {
              policy: 'evss',
              policy_action: 'access?',
              is_authorized: false,
              errors: {
                edipi: ['must be filled'],
                participant_id: ['must be filled']
              }
            }
          }
        )
      end
    end
  end
end
