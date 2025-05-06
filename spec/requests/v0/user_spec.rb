# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'

RSpec.describe 'V0::User', type: :request do
  include SchemaMatchers
  include SM::ClientHelpers

  context 'GET /v0/user - when an LOA 3 user is logged in' do
    let(:mhv_user) { build(:user, :mhv) }
    let(:v0_user_request_headers) { {} }
    let(:edipi) { '1005127153' }
    let!(:mhv_user_verification) { create(:mhv_user_verification, mhv_uuid: mhv_user.mhv_credential_uuid) }

    before do
      allow(SM::Client).to receive(:new).and_return(authenticated_client)
      allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return('Premium')
      create(:account, idme_uuid: mhv_user.uuid)
      sign_in_as(mhv_user)
      allow_any_instance_of(User).to receive(:edipi).and_return(edipi)
      VCR.use_cassette('user_eligibility_client/perform_an_eligibility_check_for_premium_user',
                       match_requests_on: %i[method sm_user_ignoring_path_param]) do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', allow_playback_repeats: true) do
          get v0_user_url, params: nil, headers: v0_user_request_headers
        end
      end
    end

    context 'dont stub mpi' do
      let(:mhv_user) { build(:user, :mhv, :no_mpi_profile) }

      it 'GET /v0/user - returns proper json' do
        assert_response :success
        expect(response).to match_response_schema('user_loa3')
      end
    end

    it 'gives me the list of available prefill forms' do
      num_enabled = 3
      FormProfile::ALL_FORMS.each { |type, form_list| num_enabled += form_list.length if Settings[type].prefill }
      expect(JSON.parse(response.body)['data']['attributes']['prefills_available'].length).to be(num_enabled)
    end

    it 'gives me the list of available services' do
      expect(JSON.parse(response.body)['data']['attributes']['services'].sort).to eq(
        [
          BackendServices::FACILITIES,
          BackendServices::HCA,
          BackendServices::EDUCATION_BENEFITS,
          BackendServices::EVSS_CLAIMS,
          BackendServices::LIGHTHOUSE,
          BackendServices::FORM526,
          BackendServices::USER_PROFILE,
          BackendServices::RX,
          BackendServices::MESSAGING,
          BackendServices::MEDICAL_RECORDS,
          BackendServices::HEALTH_RECORDS,
          BackendServices::ID_CARD,
          # BackendServices::MHV_AC, this will be false if mhv account is premium
          BackendServices::FORM_PREFILL,
          BackendServices::SAVE_IN_PROGRESS,
          BackendServices::APPEALS_STATUS,
          BackendServices::IDENTITY_PROOFED,
          BackendServices::VET360
        ].sort
      )
    end

    it 'gives me va profile cerner data' do
      va_profile = JSON.parse(response.body)['data']['attributes']['va_profile']
      expect(va_profile['is_cerner_patient']).to be false
      expect(va_profile['facilities']).to contain_exactly({ 'facility_id' => '358', 'is_cerner' => false })
    end

    it 'returns patient status' do
      va_profile = JSON.parse(response.body)['data']['attributes']['va_profile']
      expect(va_profile['va_patient']).to be true
    end

    it 'returns mhv account state info' do
      va_profile = JSON.parse(response.body)['data']['attributes']['va_profile']
      expect(va_profile['mhv_account_state']).to eq('OK')
    end

    context 'with camel header inflection' do
      let(:v0_user_request_headers) { { 'X-Key-Inflection' => 'camel' } }
      let(:mhv_user) { build(:user, :mhv, :no_mpi_profile) }

      it 'GET /v0/user - returns proper json' do
        assert_response :success
        expect(response).to match_camelized_response_schema('user_loa3')
      end
    end

    context 'with deactivated MHV account' do
      let(:mpi_profile) do
        build(:mpi_profile,
              mhv_ids: %w[12345 67890],
              active_mhv_ids: ['12345'])
      end
      let(:mhv_user) { build(:user, :mhv) }

      before do
        stub_mpi(mpi_profile)
        sign_in_as(mhv_user)
        get v0_user_url, params: nil
      end

      it 'returns deactivated mhv account state info' do
        va_profile = JSON.parse(response.body)['data']['attributes']['va_profile']
        expect(va_profile['mhv_account_state']).to eq('DEACTIVATED')
      end
    end

    context 'with multiple MHV accounts' do
      let(:mpi_profile) do
        build(:mpi_profile,
              mhv_ids: %w[12345 67890],
              active_mhv_ids: %w[12345 67890])
      end
      let(:mhv_user) { build(:user, :mhv) }

      before do
        stub_mpi(mpi_profile)
        sign_in_as(mhv_user)
        get v0_user_url, params: nil
      end

      it 'returns multiple mhv account state' do
        va_profile = JSON.parse(response.body)['data']['attributes']['va_profile']
        expect(va_profile['mhv_account_state']).to eq('MULTIPLE')
      end
    end

    context 'with missing MHV accounts' do
      let(:mhv_user) { build(:user, :mhv, mhv_ids: nil, active_mhv_ids: nil, mhv_credential_uuid: nil) }
      let!(:mhv_user_verification) { create(:mhv_user_verification, backing_idme_uuid: mhv_user.idme_uuid) }

      before do
        sign_in_as(mhv_user)
        get v0_user_url, params: nil
      end

      it 'returns none mhv account state' do
        va_profile = JSON.parse(response.body)['data']['attributes']['va_profile']
        expect(va_profile['mhv_account_state']).to eq('NONE')
      end
    end

    context 'for non VA patient' do
      let(:mhv_user) { build(:user, :mhv, :no_vha_facilities, va_patient: false) }

      before do
        sign_in_as(mhv_user)
        get v0_user_url, params: nil
      end

      it 'returns patient status correctly' do
        va_profile = JSON.parse(response.body)['data']['attributes']['va_profile']
        expect(va_profile['va_patient']).to be false
      end
    end

    context 'with an error from a 503 raised by VAProfile::ContactInformation::Service#get_person',
            :skip_va_profile_user, :skip_vet360 do
      before do
        exception  = 'the server responded with status 503'
        error_body = { 'status' => 'some service unavailable status' }
        allow_any_instance_of(VAProfile::Service).to receive(:perform).and_raise(
          Common::Client::Errors::ClientError.new(exception, 503, error_body)
        )
        get v0_user_url, params: nil
      end

      let(:body) { JSON.parse(response.body) }

      it 'returns a status of 296' do
        expect(response).to have_http_status(296)
      end

      it 'sets the vet360_contact_information to nil' do
        expect(body.dig('data', 'attributes', 'vet360_contact_information')).to be_nil
      end

      it 'returns meta.errors information', :aggregate_failures do
        error = body.dig('meta', 'errors').first

        expect(error['external_service']).to eq 'VAProfile'
        expect(error['description']).to be_present
        expect(error['status']).to eq 502
      end
    end
  end

  context 'GET /v0/user - when an LOA 1 user is logged in', :skip_mvi do
    let(:v0_user_request_headers) { {} }
    let(:edipi) { '1005127153' }

    before do
      user = new_user(:loa1)
      sign_in_as(user)
      create(:user_verification, idme_uuid: user.idme_uuid)
      allow_any_instance_of(User).to receive(:edipi).and_return(edipi)
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', allow_playback_repeats: true) do
        get v0_user_url, params: nil, headers: v0_user_request_headers
      end
    end

    it 'returns proper json' do
      expect(response).to match_response_schema('user_loa1')
    end

    it 'returns a status of 296 with errors', :aggregate_failures do
      body  = JSON.parse(response.body)
      error = body.dig('meta', 'errors').first

      expect(response).to have_http_status 296
      expect(error['external_service']).to eq 'MVI'
      expect(error['description']).to be_present
      expect(error['status']).to eq 401
    end

    context 'with camel inflection' do
      let(:v0_user_request_headers) { { 'X-Key-Inflection' => 'camel' } }

      it 'returns proper json' do
        expect(response).to match_camelized_response_schema('user_loa1')
      end
    end
  end

  context 'GET /v0/user - when an LOA 1 user is logged in - no edipi', :skip_mvi do
    let(:v0_user_request_headers) { {} }

    before do
      user = new_user(:loa1)
      sign_in_as(user)
      create(:user_verification, idme_uuid: user.idme_uuid)
      get v0_user_url, params: nil, headers: v0_user_request_headers
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

  context 'GET /v0/user - MVI Integration', :skip_mvi do
    let(:user) { create(:user, :loa3, :no_mpi_profile, icn: SecureRandom.uuid) }
    let(:edipi) { '1005127153' }

    before do
      create(:user_verification, idme_uuid: user.idme_uuid)
      VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', allow_playback_repeats: true) do
        sign_in_as(user)
        allow_any_instance_of(User).to receive(:edipi).and_return(edipi)
      end
    end

    it 'MVI error should only make a request to MVI one time per request!', :aggregate_failures do
      stub_mpi_failure
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.failed', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.success')

      body  = JSON.parse(response.body)
      error = body.dig('meta', 'errors').first

      expect(body['data']['attributes']['va_profile']).to be_nil
      expect(response).to have_http_status 296
      expect(error['external_service']).to eq 'MVI'
      expect(error['description']).to be_present
      expect(error['status']).to eq 500
    end

    it 'MVI RecordNotFound should only make a request to MVI one time per request!', :aggregate_failures do
      stub_mpi_record_not_found
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
      body  = JSON.parse(response.body)
      error = body.dig('meta', 'errors').first

      expect(body['data']['attributes']['va_profile']).to be_nil
      expect(response).to have_http_status 296
      expect(error['external_service']).to eq 'MVI'
      expect(error['description']).to be_present
      expect(error['status']).to eq 404
    end

    it 'MVI DuplicateRecords should only make a request to MVI one time per request!', :aggregate_failures do
      stub_mpi_duplicate_record
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
        .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
        .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')

      body  = JSON.parse(response.body)
      error = body.dig('meta', 'errors').first

      expect(body['data']['attributes']['va_profile']).to be_nil
      expect(response).to have_http_status 296
      expect(error['external_service']).to eq 'MVI'
      expect(error['description']).to be_present
      expect(error['status']).to eq 404
    end

    it 'MVI success should only make a request to MVI one time per multiple requests!' do
      stub_mpi_success
      expect_any_instance_of(Common::Client::Base).to receive(:perform).once.and_call_original
      expect { get v0_user_url, params: nil }
        .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
      expect { get v0_user_url, params: nil }
        .not_to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
      expect { get v0_user_url, params: nil }
        .not_to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
    end

    context 'when breakers is used' do
      let(:user2) { create(:user, :loa3, :no_mpi_profile, icn: SecureRandom.uuid) }
      let(:edipi) { '1005127153' }

      before do
        allow_any_instance_of(User).to receive(:edipi).and_return(edipi)
      end

      it 'MVI raises a breakers exception after 50% failure rate', :aggregate_failures do
        VCR.use_cassette('va_profile/veteran_status/va_profile_veteran_status_200', allow_playback_repeats: true) do
          now = Time.current
          start_time = now - 120
          Timecop.freeze(start_time)

          # starts out successful
          stub_mpi_success
          sign_in_as(user)
          expect { get v0_user_url, params: nil }
            .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
            .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
            .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')

          # encounters failure and breakers kicks in
          stub_mpi_failure
          sign_in_as(user2)
          expect { get v0_user_url, params: nil }
            .to trigger_statsd_increment('api.external_http_request.MVI.failed', times: 1, value: 1)
            .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
            .and not_trigger_statsd_increment('api.external_http_request.MVI.success')
          expect(MPI::Configuration.instance.breakers_service.latest_outage.start_time.to_i).to eq(start_time.to_i)

          # skipped because breakers is active
          stub_mpi_success
          sign_in_as(user2)
          expect { get v0_user_url, params: nil }
            .to trigger_statsd_increment('api.external_http_request.MVI.skipped', times: 1, value: 1)
            .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
            .and not_trigger_statsd_increment('api.external_http_request.MVI.success')
          expect(MPI::Configuration.instance.breakers_service.latest_outage.ended?).to be(false)
          Timecop.freeze(now)

          # sufficient time has elapsed that new requests are made, resulting in success
          sign_in_as(user2)
          expect { get v0_user_url, params: nil }
            .to trigger_statsd_increment('api.external_http_request.MVI.success', times: 1, value: 1)
            .and not_trigger_statsd_increment('api.external_http_request.MVI.skipped')
            .and not_trigger_statsd_increment('api.external_http_request.MVI.failed')
          expect(response).to have_http_status(:ok)
          expect(MPI::Configuration.instance.breakers_service.latest_outage.ended?).to be(true)
          Timecop.return
        end
      end
    end
  end

  def new_user(type = :loa3)
    user = build(:user, type, icn: SecureRandom.uuid, uuid: rand(1000..100_000))
    create(:account, idme_uuid: user.uuid)
    user
  end

  def stub_mpi_failure
    stub_mpi_external_request File.read('spec/support/mpi/find_candidate_soap_fault.xml')
  end

  def stub_mpi_record_not_found
    stub_mpi_external_request File.read('spec/support/mpi/find_candidate_no_subject_response.xml')
  end

  def stub_mpi_duplicate_record
    stub_mpi_external_request File.read('spec/support/mpi/find_candidate_multiple_match_response.xml')
  end

  def stub_mpi_success
    stub_mpi_external_request File.read('spec/support/mpi/find_candidate_response.xml')
  end

  def stub_mpi_external_request(file)
    stub_request(:post, IdentitySettings.mvi.url)
      .to_return(status: 200, headers: { 'Content-Type' => 'text/xml' }, body: file)
  end
end
