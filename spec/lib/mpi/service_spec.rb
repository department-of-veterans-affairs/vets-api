# frozen_string_literal: true

require 'rails_helper'
require 'mpi/service'

describe MPI::Service do
  let(:user_hash) do
    {
      first_name: 'Mitchell',
      last_name: 'Jenkins',
      middle_name: 'G',
      birth_date: '1949-03-04',
      ssn: '796122306'
    }
  end

  let(:user) { build(:user, :loa3, user_hash) }
  let(:icn_with_aaid) { '1008714701V416111^NI^200M^USVHA' }
  let(:not_found) { MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:not_found] }
  let(:server_error) { MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:server_error] }

  let(:mvi_profile) do
    build(
      :mpi_profile_response,
      :missing_attrs,
      :address_austin,
      given_names: %w[Mitchell G],
      vha_facility_ids: [],
      vha_facility_hash: nil,
      sec_id: '1008714701',
      birls_id: '796122306',
      birls_ids: ['796122306'],
      historical_icns: nil,
      icn_with_aaid: icn_with_aaid,
      person_types: [],
      full_mvi_ids: [
        '1008714701V416111^NI^200M^USVHA^P',
        '796122306^PI^200BRLS^USVBA^A',
        '9100792239^PI^200CORP^USVBA^A',
        '1008714701^PN^200PROV^USDVA^A',
        '32383600^PI^200CORP^USVBA^L'
      ],
      search_token: nil,
      id_theft_flag: false
    )
  end

  describe '.add_person' do
    before do
      expect(MPI::Messages::AddPersonMessage).to receive(:new).once.and_call_original
    end

    context 'valid_request when user has no ids' do
      let(:user) { build(:user_with_no_ids) }

      let(:mvi_codes) do
        {
          birls_id: '111985523',
          participant_id: '32397028'
        }
      end

      it 'runs a proxy add for birls and corp ids' do
        VCR.use_cassette('mpi/add_person/add_person_success') do
          response = subject.add_person(user)
          expect(response.status).to eq('OK')
          expect(response.mvi_codes).to have_deep_attributes(mvi_codes)
        end
      end

      it 'returns no errors' do
        VCR.use_cassette('mpi/add_person/add_person_success') do
          response = subject.add_person(user)

          expect(response.error).to be_nil
        end
      end
    end

    context 'valid_request when user already has both ids' do
      let(:user) { build(:user, :loa3) }

      let(:mvi_codes) do
        {
          birls_id: '796104437',
          participant_id: '13367440',
          other: [{ codeSystem: '2.16.840.1.113883.4.349', code: 'WRN206', displayName: 'Existing Key Identifier' }]
        }
      end

      it 'runs a proxy add for birls and corp ids' do
        VCR.use_cassette('mpi/add_person/add_person_already_exists') do
          response = subject.add_person(user)
          expect(response.status).to eq('OK')
          expect(response.mvi_codes).to have_deep_attributes(mvi_codes)
        end
      end

      it 'returns no errors' do
        VCR.use_cassette('mpi/add_person/add_person_success') do
          response = subject.add_person(user)

          expect(response.error).to be_nil
        end
      end
    end

    context 'invalid requests' do
      it 'responds with a SERVER_ERROR if request is invalid', :aggregate_failures do
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/add_person/add_person_invalid_request') do
          response = subject.add_person(user)
          exception = response.error.errors.first

          expect(response.class).to eq MPI::Responses::AddPersonResponse
          expect(response.status).to eq server_error
          expect(response.mvi_codes).to be_nil
          expect(exception.title).to eq 'Bad Gateway'
          expect(exception.code).to eq 'MVI_502'
          expect(exception.status).to eq '502'
          expect(exception.source).to eq MPI::Service
        end
      end

      it 'responds with a SERVER_ERROR if the user has duplicate keys in the system', :aggregate_failures do
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/add_person/add_person_duplicate') do
          response = subject.add_person(user)
          exception = response.error.errors.first

          expect(response.class).to eq MPI::Responses::AddPersonResponse
          expect(response.status).to eq server_error
          expect(response.mvi_codes).to be_nil
          expect(exception.title).to eq 'Duplicate Keys'
          expect(exception.code).to eq 'MVI_502_DUP'
          expect(exception.status).to eq '502'
          expect(exception.source).to eq MPI::Service
        end
      end
    end

    context 'with an MVI timeout' do
      let(:base_path) { MPI::Configuration.instance.base_path }

      it 'raises a service error', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI add_person error: Gateway timeout',
          :warn
        )
        response = subject.add_person(user)

        exception = response.error.errors.first

        expect(response.class).to eq MPI::Responses::AddPersonResponse
        expect(response.status).to eq server_error
        expect(response.mvi_codes).to be_nil
        expect(exception.title).to eq 'Gateway timeout'
        expect(exception.code).to eq 'MVI_504'
        expect(exception.status).to eq '504'
        expect(exception.source).to eq MPI::Service
      end
    end

    context 'with an ongoing breakers outage' do
      it 'returns the correct thing', :aggregate_failures do
        MPI::Configuration.instance.breakers_service.begin_forced_outage!
        expect(Raven).to receive(:extra_context).once
        response = subject.add_person(user)

        exception = response.error.errors.first

        expect(response.class).to eq MPI::Responses::AddPersonResponse
        expect(response.status).to eq server_error
        expect(response.mvi_codes).to be_nil
        expect(exception.title).to eq 'Service unavailable'
        expect(exception.code).to eq 'MVI_503'
        expect(exception.status).to eq '503'
        expect(exception.source).to eq MPI::Service
      end
    end
  end

  describe '.find_profile with orch_search' do
    let(:user) { build(:user, :loa3, user_hash) }

    describe '.find_profile with attributes' do
      context 'valid request' do
        let(:user_hash) do
          {
            first_name: 'MARK',
            last_name: 'WEBB',
            middle_name: '',
            birth_date: '1950-10-04',
            ssn: '796104437',
            edipi: '1013590059'
          }
        end

        it 'calls the find profile with an orchestrated search', run_at: 'Thu, 06 Feb 2020 23:59:36 GMT' do
          allow(SecureRandom).to receive(:uuid).and_return('b4d9a901-8f2f-46c0-802f-3eeb99c51dfb')
          allow(Socket).to receive(:ip_address_list).and_return([Addrinfo.ip('1.1.1.1')])
          allow(Settings.mvi).to receive(:vba_orchestration).and_return(true)

          VCR.use_cassette('mpi/find_candidate/orch_search_with_attributes', VCR::MATCH_EVERYTHING) do
            response = described_class.new.find_profile(user, orch_search: true)
            expect(response.status).to eq('OK')
            expect(response.profile.icn).to eq('1008709396V637156')
          end
        end
      end

      context 'with an invalid user' do
        let(:user) { build(:user, :loa1) }

        it 'raises an unprocessable entity error' do
          allow(user).to receive(:edipi).and_return(nil)

          expect { described_class.new.find_profile(user, orch_search: true) }.to raise_error do |error|
            expect(error).to be_a(Common::Exceptions::UnprocessableEntity)
            expect(error.errors.first.source).to eq('MPI Service')
            expect(error.errors.first.detail).to eq('User is missing EDIPI')
          end
        end
      end
    end
  end

  describe '.find_profile with icn', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
    before do
      expect(MPI::Messages::FindProfileMessageIcn).to receive(:new).once.and_call_original
    end

    context 'valid requests' do
      it 'fetches profile when icn has ^NI^200M^USVHA^P' do
        allow(user).to receive(:mhv_icn).and_return('1008714701V416111^NI^200M^USVHA^P')

        VCR.use_cassette('mpi/find_candidate/valid_icn_full') do
          profile = mvi_profile
          profile['search_token'] = 'WSDOC1908201553145951848240311'
          expect(Raven).to receive(:tags_context).once.with(mvi_find_profile: 'icn')
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(profile)
        end
      end

      it 'fetches profile when icn has ^NI' do
        allow(user).to receive(:mhv_icn).and_return('1008714701V416111^NI')

        VCR.use_cassette('mpi/find_candidate/valid_icn_ni_only') do
          profile = mvi_profile
          profile['search_token'] = 'WSDOC1908201553117051423642755'
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(profile)
        end
      end

      it 'fetches profile when icn is just basic icn' do
        allow(user).to receive(:mhv_icn).and_return('1008714701V416111')

        VCR.use_cassette('mpi/find_candidate/valid_icn_without_ni') do
          profile = mvi_profile
          profile['search_token'] = 'WSDOC1908201553094460697640189'
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(profile)
        end
      end

      it 'correctly parses vet360 id if it exists', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
        allow(user).to receive(:mhv_icn).and_return('1008787551V609092^NI^200M^USVHA^P')

        VCR.use_cassette('mpi/find_candidate/valid_vet360_id') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile['vet360_id']).to eq('80')
        end
      end

      it 'fetches historical icns if they exist', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
        allow(user).to receive(:mhv_icn).and_return('1008787551V609092^NI^200M^USVHA^P')
        allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')

        match = { match_requests_on: %i[method uri headers body] }
        VCR.use_cassette('mpi/find_candidate/historical_icns_with_icn', match) do
          response = subject.find_profile(user, search_type: MPI::Constants::CORRELATION_WITH_ICN_HISTORY)
          expect(response.status).to eq('OK')
          expect(response.profile['historical_icns']).to eq(
            %w[1008692852V724999 1008787550V443247 1008787485V229771 1008795715V162680
               1008795714V030791 1008795629V076564 1008795718V643356]
          )
        end
      end

      it 'fetches no historical icns if none exist', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
        allow(user).to receive(:mhv_icn).and_return('1008710003V120120^NI^200M^USVHA^P')
        allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')

        VCR.use_cassette('mpi/find_candidate/historical_icns_empty', VCR::MATCH_EVERYTHING) do
          response = subject.find_profile(user, search_type: MPI::Constants::CORRELATION_WITH_ICN_HISTORY)
          expect(response.status).to eq('OK')
          expect(response.profile['historical_icns']).to eq([])
        end
      end

      it 'fetches id_theft flag' do
        allow(user).to receive(:mhv_icn).and_return('1012870264V741864')

        VCR.use_cassette('mpi/find_candidate/valid_id_theft_flag') do
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile['id_theft_flag']).to eq(true)
        end
      end

      it 'returns no errors' do
        allow(user).to receive(:mhv_icn).and_return('1008714701V416111^NI^200M^USVHA^P')

        VCR.use_cassette('mpi/find_candidate/valid_icn_full') do
          response = subject.find_profile(user)

          expect(response.error).to be_nil
        end
      end
    end

    context 'invalid requests' do
      it 'responds with a SERVER_ERROR if ICN is invalid', :aggregate_failures do
        allow(user).to receive(:mhv_icn).and_return('invalid-icn-is-here^NI')
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/find_candidate/invalid_icn') do
          response = subject.find_profile(user)

          server_error_502_expectations_for(response)
        end
      end

      it 'responds with a SERVER_ERROR if ICN has no matches', :aggregate_failures do
        allow(user).to receive(:mhv_icn).and_return('1008714781V416999')
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/find_candidate/icn_not_found') do
          response = subject.find_profile(user)

          server_error_502_expectations_for(response)
        end
      end
    end
  end

  describe '.find_profile with edipi', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
    before do
      expect(MPI::Messages::FindProfileMessageEdipi).to receive(:new).once.and_call_original
    end

    context 'valid requests' do
      it 'fetches profile when no mhv_icn exists but edipi is present' do
        allow(user).to receive(:edipi).and_return('1025062341')

        VCR.use_cassette('mpi/find_candidate/edipi_present') do
          expect(Raven).to receive(:tags_context).once.with(mvi_find_profile: 'edipi')
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile.given_names).to eq(%w[Benjamiin Two])
          expect(response.profile.family_name).to eq('Chesney')
          expect(response.profile.full_mvi_ids).to eq(
            [
              '1061810166V222862^NI^200M^USVHA^P',
              '0000001061810166V222862000000^PI^200ESR^USVHA^A',
              '1025062341^NI^200DOD^USDOD^A',
              'UNK^PI^200BRLS^USVBA^FAULT',
              'UNK^PI^200CORP^USVBA^FAULT'
            ]
          )
        end
      end
    end
  end

  describe '.find_profile without icn' do
    context 'valid request' do
      before do
        expect(MPI::Messages::FindProfileMessageEdipi).to receive(:new).once.and_call_original
      end

      it 'calls the find_profile endpoint with a find candidate message' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          profile = mvi_profile
          profile['search_token'] = 'WSDOC1908281447208280163390431'
          expect(Raven).to receive(:tags_context).once.with(mvi_find_profile: 'edipi')
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile).to have_deep_attributes(profile)
        end
      end

      context 'with historical icns' do
        let(:user_hash) do
          {
            first_name: 'RFIRST',
            last_name: 'RLAST',
            birth_date: '19790812',
            gender: 'M',
            ssn: '768598574'
          }
        end

        it 'fetches historical icns when available', run_at: 'Thu, 29 Aug 2019 13:56:24 GMT' do
          allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')

          VCR.use_cassette('mpi/find_candidate/historical_icns_with_edipi', VCR::MATCH_EVERYTHING) do
            response = subject.find_profile(user, search_type: MPI::Constants::CORRELATION_WITH_ICN_HISTORY)
            expect(response.status).to eq('OK')
            expect(response.profile['historical_icns']).to eq(
              %w[1008692852V724999 1008787550V443247 1008787485V229771 1008795715V162680
                 1008795714V030791 1008795629V076564 1008795718V643356]
            )
          end
        end
      end

      context 'without gender' do
        let(:user_hash) do
          {
            first_name: 'Mitchell',
            last_name: 'Jenkins',
            middle_name: 'G',
            birth_date: '1949-03-04',
            ssn: '796122306',
            gender: nil
          }
        end

        it 'calls the find_profile endpoint with a find candidate message' do
          VCR.use_cassette('mpi/find_candidate/valid_no_gender') do
            profile = mvi_profile
            profile['search_token'] = 'WSDOC1908281514193450364096012'
            response = subject.find_profile(user)
            expect(response.profile).to have_deep_attributes(profile)
          end
        end
      end
    end

    context 'when a MVI invalid request response is returned' do
      it 'raises a invalid request error', :aggregate_failures do
        invalid_xml = File.read('spec/support/mpi/find_candidate_invalid_request.xml')
        allow_any_instance_of(MPI::Service).to receive(:create_profile_message).and_return(invalid_xml)
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/find_candidate/invalid') do
          response = subject.find_profile(user)
          server_error_502_expectations_for(response)
        end
      end
    end

    context 'when a MVI internal system problem response is returned' do
      let(:body) { File.read('spec/support/mpi/find_candidate_ar_code_database_error_response.xml') }

      it 'raises a invalid request error', :aggregate_failures do
        expect(subject).to receive(:log_exception_to_sentry)

        stub_request(:post, Settings.mvi.url).to_return(status: 200, body: body)
        response = subject.find_profile(user)
        server_error_502_expectations_for(response)
      end
    end

    context 'with an MVI timeout' do
      let(:base_path) { MPI::Configuration.instance.base_path }

      it 'raises a service error', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI find_profile error: Gateway timeout',
          :warn
        )
        response = subject.find_profile(user)

        server_error_504_expectations_for(response)
      end
    end

    context 'when a status of 500 is returned' do
      it 'raises a request failure error', :aggregate_failures do
        allow_any_instance_of(MPI::Service).to receive(:create_profile_message).and_return('<nobeuno></nobeuno>')
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI find_profile error: SOAP HTTP call failed',
          :warn
        )
        VCR.use_cassette('mpi/find_candidate/five_hundred') do
          response = subject.find_profile(user)
          server_error_504_expectations_for(response)
        end
      end
    end

    context 'when no subject is returned in the response body' do
      before do
        expect(MPI::Messages::FindProfileMessageEdipi).to receive(:new).once.and_call_original
      end

      let(:user_hash) do
        {
          first_name: 'Earl',
          last_name: 'Stephens',
          middle_name: 'M',
          birth_date: '1978-06-11',
          ssn: '796188587'
        }
      end

      it 'returns not found, does not log sentry', :aggregate_failures do
        VCR.use_cassette('mpi/find_candidate/no_subject') do
          expect(subject).not_to receive(:log_exception_to_sentry)
          response = subject.find_profile(user)

          record_not_found_404_expectations_for(response)
        end
      end

      context 'with an invalid historical icn user' do
        let(:user_hash) do
          {
            first_name: 'sdf',
            last_name: 'sdgsdf',
            birth_date: '19800812',
            gender: 'M',
            ssn: '111222333'
          }
        end

        it 'returns not found for COMP2 requests, does not log sentry', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
          allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')

          VCR.use_cassette('mpi/find_candidate/historical_icns_user_not_found', VCR::MATCH_EVERYTHING) do
            expect(subject).not_to receive(:log_exception_to_sentry)
            response = subject.find_profile(user, search_type: MPI::Constants::CORRELATION_WITH_ICN_HISTORY)

            record_not_found_404_expectations_for(response)
          end
        end
      end

      context 'with an ongoing breakers outage' do
        it 'returns the correct thing', :aggregate_failures do
          MPI::Configuration.instance.breakers_service.begin_forced_outage!
          expect(Raven).to receive(:extra_context).once
          response = subject.find_profile(user)

          server_error_503_expectations_for(response)
        end
      end
    end

    context 'when MVI returns 500 but VAAFI sends 200' do
      before do
        expect(MPI::Messages::FindProfileMessageEdipi).to receive(:new).once.and_call_original
      end

      %w[internal_server_error internal_server_error_2].each do |cassette|
        it 'raises an Common::Client::Errors::HTTPError', :aggregate_failures do
          expect(subject).to receive(:log_message_to_sentry).with(
            'MVI find_profile error: SOAP service returned internal server error',
            :warn
          )
          VCR.use_cassette("mpi/find_candidate/#{cassette}") do
            response = subject.find_profile(user)

            server_error_504_expectations_for(response)
          end
        end
      end
    end

    context 'when MVI multiple match failure response' do
      before do
        expect(MPI::Messages::FindProfileMessageEdipi).to receive(:new).once.and_call_original
      end

      it 'raises MPI::Errors::RecordNotFound', :aggregate_failures do
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/find_candidate/failure_multiple_matches') do
          response = subject.find_profile(user)

          record_not_found_404_expectations_for(response)
        end
      end
    end
  end

  describe '.find_profile monitoring' do
    context 'with a successful request' do
      it 'increments find_profile total' do
        allow(user).to receive(:mhv_icn)

        allow(StatsD).to receive(:increment)
        VCR.use_cassette('mpi/find_candidate/valid') do
          subject.find_profile(user)
        end
        expect(StatsD).to have_received(:increment).with('api.mvi.find_profile.total')
      end

      it 'logs the request and response data' do
        expect do
          VCR.use_cassette('mpi/find_candidate/valid') do
            Settings.mvi.pii_logging = true
            subject.find_profile(user)
            Settings.mvi.pii_logging = false
          end
        end.to change(PersonalInformationLog, :count).by(1)
      end
    end

    context 'with an unsuccessful request' do
      it 'increments find_profile fail and total', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(StatsD).to receive(:increment).once.with(
          'api.mvi.find_profile.fail', tags: ['error:CommonExceptionsGatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.mvi.find_profile.total')
        response = subject.find_profile(user)

        server_error_504_expectations_for(response)
      end
    end
  end

  describe '.add_person monitoring' do
    context 'with a successful request' do
      let(:user) { build(:user_with_no_ids) }

      it 'increments add_person total' do
        allow(StatsD).to receive(:increment)
        VCR.use_cassette('mpi/add_person/add_person_success') do
          subject.add_person(user)
        end
        expect(StatsD).to have_received(:increment).with('api.mvi.add_person.total')
      end
    end

    context 'with an unsuccessful request' do
      it 'increments add_person fail and total', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(StatsD).to receive(:increment).once.with(
          'api.mvi.add_person.fail', tags: ['error:CommonExceptionsGatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.mvi.add_person.total')
        response = subject.add_person(user)

        exception = response.error.errors.first

        expect(response.class).to eq MPI::Responses::AddPersonResponse
        expect(response.status).to eq server_error
        expect(response.mvi_codes).to be_nil
        expect(exception.title).to eq 'Gateway timeout'
        expect(exception.code).to eq 'MVI_504'
        expect(exception.status).to eq '504'
        expect(exception.source).to eq MPI::Service
      end
    end
  end
end

def server_error_502_expectations_for(response)
  exception = response.error.errors.first

  expect(response.class).to eq MPI::Responses::FindProfileResponse
  expect(response.status).to eq server_error
  expect(response.profile).to be_nil
  expect(exception.title).to eq 'Bad Gateway'
  expect(exception.code).to eq 'MVI_502'
  expect(exception.status).to eq '502'
  expect(exception.source).to eq MPI::Service
end

def server_error_503_expectations_for(response)
  exception = response.error.errors.first

  expect(response.class).to eq MPI::Responses::FindProfileResponse
  expect(response.status).to eq server_error
  expect(response.profile).to be_nil
  expect(exception.title).to eq 'Service unavailable'
  expect(exception.code).to eq 'MVI_503'
  expect(exception.status).to eq '503'
  expect(exception.source).to eq MPI::Service
end

def server_error_504_expectations_for(response)
  exception = response.error.errors.first

  expect(response.class).to eq MPI::Responses::FindProfileResponse
  expect(response.status).to eq server_error
  expect(response.profile).to be_nil
  expect(exception.title).to eq 'Gateway timeout'
  expect(exception.code).to eq 'MVI_504'
  expect(exception.status).to eq '504'
  expect(exception.source).to eq MPI::Service
end

def record_not_found_404_expectations_for(response)
  exception = response.error.errors.first

  expect(response.class).to eq MPI::Responses::FindProfileResponse
  expect(response.status).to eq not_found
  expect(response.profile).to be_nil
  expect(exception.title).to eq 'Record not found'
  expect(exception.code).to eq 'MVI_404'
  expect(exception.status).to eq '404'
  expect(exception.source).to eq MPI::Service
end
