# frozen_string_literal: true

require 'rails_helper'
require 'backend_services'

RSpec.describe 'Fetching user data', type: :request do
  include SchemaMatchers

  let(:token) { 'abracadabra-open-sesame' }

  context 'when an LOA 3 user is logged in' do
    let(:mhv_user) { build(:user, :mhv) }

    before(:each) do
      Session.create(uuid: mhv_user.uuid, token: token)
      allow_any_instance_of(MhvAccountTypeService).to receive(:mhv_account_type).and_return('Premium')
      mhv_account = double('MhvAccount', creatable?: false, upgradable?: false, account_state: 'upgraded')
      allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
      allow(mhv_account).to receive(:terms_and_conditions_accepted?).and_return(true)
      allow(mhv_account).to receive(:needs_terms_acceptance?).and_return(false)
      User.create(mhv_user)
      create(:account, idme_uuid: mhv_user.uuid)
    end

    before do
      auth_header = { 'Authorization' => "Token token=#{token}" }
      get v0_user_url, nil, auth_header
    end

    it 'GET /v0/user - returns proper json' do
      assert_response :success
      expect(response).to match_response_schema('user_loa3')
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
          # BackendServices::MHV_AC, this will be false if mhv account is premium
          BackendServices::FORM_PREFILL,
          BackendServices::SAVE_IN_PROGRESS,
          BackendServices::APPEALS_STATUS,
          BackendServices::IDENTITY_PROOFED,
          BackendServices::VET360
        ].sort
      )
    end
  end

  context 'when an LOA 1 user is logged in', :skip_mvi do
    let(:loa1_user) { build(:user, :loa1) }

    before do
      Session.create(uuid: loa1_user.uuid, token: token)
      User.create(loa1_user)
      create(:account, idme_uuid: loa1_user.uuid)

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

  context 'when an LOA3 user is logged in', :skip_mvi do
    let(:loa3_user) { build(:user, :loa3) }
    let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }

    before do
      Session.create(uuid: loa3_user.uuid, token: token)
      User.create(loa3_user)
      create(:account, idme_uuid: loa3_user.uuid)
    end

    it 'GET /v0/user - for MVI error should only make a request to MVI one time per request!' do
      stub_mvi_failure
      expect_any_instance_of(Common::Client::Base).to receive(:perform).and_call_original
      expect { get v0_user_url, nil, auth_header }
        .to trigger_statsd_increment('api.external_http_request.MVI.failed', times: 1, value: 1)
    end

    it 'GET /v0/user - for MVI success should only make a request to MVI one time per multiple requests!' do
      stub_mvi_success
      expect_any_instance_of(Common::Client::Base).to receive(:perform).once.and_call_original
      expect { get v0_user_url, nil, auth_header }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
      expect { get v0_user_url, nil, auth_header }
        .not_to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
      expect { get v0_user_url, nil, auth_header }
        .not_to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
    end

    # The successes are not registering as 20 requests because we cache after the first one on a user basis
    it 'GET /v0/user - for MVI raises a breakers exception after 50% failure rate' do
      allow_any_instance_of(Mvi).to receive(:save).and_return(true)

      now = Time.current
      start_time = now - 120
      Timecop.freeze(start_time)

      stub_mvi_success
      2.times do
        get v0_user_url, nil, auth_header
        expect(response.status).to eq(200)
      end

      stub_mvi_failure
      2.times do
        get v0_user_url, nil, auth_header
        expect(response.status).to eq(200)
      end

      expect do
        get v0_user_url, nil, auth_header
      end.to trigger_statsd_increment('api.external_http_request.MVI.skipped', times: 1, value: 1)

      get v0_user_url, nil, auth_header
      expect(response.status).to eq(200)

      Timecop.freeze(now)
      stub_mvi_success
      get v0_user_url, nil, auth_header
      expect(response.status).to eq(200)
    end

    def stub_mvi_failure
      fail_XML = File.read('spec/support/mvi/find_candidate_soap_fault.xml')
      stub_request(:post, Settings.mvi.url)
        .to_return(status: 200, headers: { 'Content-Type' => 'text/xml' }, body: fail_XML)
    end

    def stub_mvi_success
      success_XML = File.read('spec/support/mvi/find_candidate_response.xml')
      stub_request(:post, Settings.mvi.url)
        .to_return(status: 200, headers: { 'Content-Type' => 'text/xml' }, body: success_XML)
    end
  end
end
