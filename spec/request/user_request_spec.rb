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
      allow(mhv_account).to receive(:user_uuid).and_return(mhv_user.uuid)
      allow(mhv_account).to receive(:terms_and_conditions_accepted?).and_return(true)
      allow(mhv_account).to receive(:needs_terms_acceptance?).and_return(false)
      allow(mhv_account).to receive(:user=).and_return(mhv_user)
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

    context 'with a 503 raised by Vet360::ContactInformation::Service#get_person', skip_vet360: true do
      let(:auth_header) { { 'Authorization' => "Token token=#{token}" } }

      before do
        exception   = 'the server responded with status 503'
        error_body  = { 'status' => 'some service unavailable status' }
        allow_any_instance_of(Vet360::Service).to receive(:perform).and_raise(
          Common::Client::Errors::ClientError.new(exception, 503, error_body)
        )
      end

      it 'returns a 200', :aggregate_failures do
        get v0_user_url, nil, auth_header

        body = JSON.parse(response.body)

        expect(response.status).to eq(200)
        expect(body.dig('data', 'attributes', 'vet360_contact_information')).to eq({})
      end
    end
  end

  context 'when an LOA 1 user is logged in', :skip_mvi do
    let(:auth_header) { new_user_auth_header(:loa1) }

    before do
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

  context 'MVI Integration', :skip_mvi do
    let(:auth_header) { new_user_auth_header }

    it 'GET /v0/user - for MVI error should only make a request to MVI one time per request!' do
      stub_mvi_failure
      expect { get v0_user_url, nil, auth_header }
        .to trigger_statsd_increment('api.external_http_request.MVI.failed', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.success')

      expect(JSON.parse(response.body)['data']['attributes']['va_profile'])
        .to eq('status' => 'SERVER_ERROR')
    end

    it 'GET /v0/user - for MVI RecordNotFound should only make a request to MVI one time per request!' do
      stub_mvi_record_not_found
      expect { get v0_user_url, nil, auth_header }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')

      expect(JSON.parse(response.body)['data']['attributes']['va_profile'])
        .to eq('status' => 'NOT_FOUND')
    end

    it 'GET /v0/user - for MVI DuplicateRecords should only make a request to MVI one time per request!' do
      stub_mvi_duplicate_record
      expect { get v0_user_url, nil, auth_header }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')

      expect(JSON.parse(response.body)['data']['attributes']['va_profile'])
        .to eq('status' => 'NOT_FOUND')
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

    it 'GET /v0/user - for MVI raises a breakers exception after 50% failure rate' do
      now = Time.current
      start_time = now - 120
      Timecop.freeze(start_time)
      # Starts out successful
      stub_mvi_success
      expect { get v0_user_url, nil, new_user_auth_header }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')

      # Encounters failure and breakers kicks in
      stub_mvi_failure
      1.times do |_count|
        expect { get v0_user_url, nil, new_user_auth_header }
          .to trigger_statsd_increment('api.external_http_request.MVI.failed', times: 1, value: 1)
          .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
          .and not_trigger_statsd_increment('api.external_http_request.MVI.success')
      end
      expect(MVI::Configuration.instance.breakers_service.latest_outage.start_time.to_i).to eq(start_time.to_i)

      # skipped because breakers is active
      stub_mvi_success
      expect { get v0_user_url, nil, new_user_auth_header }
        .to trigger_statsd_increment('api.external_http_request.MVI.skipped', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.success')
      expect(MVI::Configuration.instance.breakers_service.latest_outage.ended?).to eq(false)
      Timecop.freeze(now)
      # sufficient time has elasped that new requests are made, resulting in succses
      expect { get v0_user_url, nil, new_user_auth_header }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
      expect(response.status).to eq(200)
      expect(MVI::Configuration.instance.breakers_service.latest_outage.ended?).to eq(true)
    end
  end

  def new_user_auth_header(type = :loa3)
    user = build(:user, type, uuid: rand(1000..100_000))
    session = Session.create(uuid: user.uuid, token: token)
    User.create(user)
    create(:account, idme_uuid: user.uuid)
    { 'Authorization' => "Token token=#{session.token}" }
  end

  def stub_mvi_failure
    stub_mvi_external_request File.read('spec/support/mvi/find_candidate_soap_fault.xml')
  end

  def stub_mvi_record_not_found
    stub_mvi_external_request File.read('spec/support/mvi/find_candidate_no_subject.xml')
  end

  def stub_mvi_duplicate_record
    stub_mvi_external_request File.read('spec/support/mvi/find_candidate_multiple_match_response.xml')
  end

  def stub_mvi_success
    stub_mvi_external_request File.read('spec/support/mvi/find_candidate_response.xml')
  end

  def stub_mvi_external_request(file)
    stub_request(:post, Settings.mvi.url)
      .to_return(status: 200, headers: { 'Content-Type' => 'text/xml' }, body: file)
  end
end
