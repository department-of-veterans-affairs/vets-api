# frozen_string_literal: true

require 'rails_helper'
require 'backend_services'

RSpec.describe 'Fetching user data', type: :request do
  include SchemaMatchers

  let(:token) { 'abracadabra-open-sesame' }
  let(:unprotected_services) { %w[facilities hca edu-benefits form-save-in-progress form-prefill].sort }
  let(:all_services) do
    services = unprotected_services
    services += Authorization::MHV_BASED_SERVICES
    services << Authorization::EVSS_CLAIMS
    services << Authorization::USER_PROFILE
    services << Authorization::APPEALS_STATUS
    services << Authorization::IDENTITY_PROOFED
    services.sort
  end

  context 'when an LOA 3 user is logged in' do
    let(:mhv_user) { build(:user, :mhv) }

    before do
      Session.create(uuid: mhv_user.uuid, token: token)
      mhv_account = double('MhvAccount', account_state: 'upgraded')
      allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
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
        all_services
      )
    end

    it 'gives me the list of available prefill forms' do
      num_enabled = 0
      num_enabled += FormProfile::EDU_FORMS.length if Settings.edu.prefill
      num_enabled += FormProfile::HCA_FORMS.length if Settings.hca.prefill
      num_enabled += FormProfile::PENSION_BURIAL_FORMS.length if Settings.pension_burial.prefill
      num_enabled += FormProfile::VIC_FORMS.length if Settings.vic.prefill
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
        unprotected_services << Authorization::USER_PROFILE
      )
    end
  end
end
