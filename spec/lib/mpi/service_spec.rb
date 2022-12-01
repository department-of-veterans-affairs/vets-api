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
  let(:code_system) { '2.16.840.1.113883.5.1100' }
  let(:mpi_error_code) { 'INTERR' }
  let(:ack_detail_code) { 'AE' }
  let(:error_texts) { ['Internal System Error'] }
  let(:error_display_name) { 'Internal System Error' }
  let(:id_extension) { '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a' }
  let(:transaction_id) { '4bae058f5e3cb4a300385c30' }
  let(:add_person_error_details) do
    { other: [{ codeSystem: code_system,
                code: mpi_error_code,
                displayName: error_display_name }],
      transaction_id: transaction_id,
      error_details: { ack_detail_code: ack_detail_code,
                       id_extension: id_extension,
                       error_texts: error_texts } }
  end
  let(:find_profile_error_details) do
    { error_details: { ack_detail_code: ack_detail_code,
                       id_extension: id_extension,
                       error_texts: error_texts } }
  end

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
      mhv_ien: nil,
      mhv_iens: [],
      edipi: nil,
      edipis: [],
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
      id_theft_flag: false,
      transaction_id: transaction_id
    )
  end

  describe '.add_person_proxy' do
    before do
      expect(MPI::Messages::AddPersonProxyAddMessage).to receive(:new).once.and_call_original
    end

    context 'valid_request when user has no ids' do
      let(:user) { build(:user_with_no_ids) }

      let(:mvi_codes) do
        {
          birls_id: '111985523',
          participant_id: '32397028',
          transaction_id: '4bae058f5e3db50000682d01'
        }
      end

      it 'runs a proxy add for birls and corp ids' do
        VCR.use_cassette('mpi/add_person/add_person_success') do
          response = subject.add_person_proxy(user)
          expect(response.status).to eq('OK')
          expect(response.mvi_codes).to have_deep_attributes(mvi_codes)
        end
      end

      it 'returns no errors' do
        VCR.use_cassette('mpi/add_person/add_person_success') do
          response = subject.add_person_proxy(user)

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
          transaction_id: '4bae058f5e3cb2c800274633',
          other: [{ codeSystem: MPI::Constants::VA_ROOT_OID, code: 'WRN206', displayName: 'Existing Key Identifier' }]
        }
      end

      it 'runs a proxy add for birls and corp ids' do
        VCR.use_cassette('mpi/add_person/add_person_already_exists') do
          response = subject.add_person_proxy(user)
          expect(response.status).to eq('OK')
          expect(response.mvi_codes).to have_deep_attributes(mvi_codes)
        end
      end

      it 'returns no errors' do
        VCR.use_cassette('mpi/add_person/add_person_success') do
          response = subject.add_person_proxy(user)

          expect(response.error).to be_nil
        end
      end
    end

    context 'invalid requests' do
      context 'generic invalid request' do
        let(:transaction_id) { '4bae058f5e3cb6080028a411' }

        it 'responds with a SERVER_ERROR if request is invalid', :aggregate_failures do
          expect(subject).to receive(:log_exception_to_sentry)

          VCR.use_cassette('mpi/add_person/add_person_invalid_request') do
            response = subject.add_person_proxy(user)
            exception = response.error.errors.first
            mpi_error_details = response.error.original_body

            expect(response.class).to eq MPI::Responses::AddPersonResponse
            expect(response.status).to eq server_error
            expect(response.mvi_codes).to be_nil
            expect(exception.title).to eq 'Bad Gateway'
            expect(exception.code).to eq 'MVI_502'
            expect(exception.status).to eq '502'
            expect(exception.source).to eq MPI::Service

            expect(mpi_error_details).to eq(add_person_error_details)
          end
        end
      end

      context 'request with duplicate keys' do
        let(:code_system) { '2.16.840.1.113883.5.4' }
        let(:mpi_error_code) { 'Key205' }
        let(:error_texts) { ['identified as a duplicate'] }
        let(:error_display_name) { 'Duplicate Key Identifier' }
        let(:id_extension) { '200VGOV-ac8c9bae-cd12-4609-811c-00bde47373bf' }

        it 'responds with a SERVER_ERROR if the user has duplicate keys in the system', :aggregate_failures do
          expect(subject).to receive(:log_exception_to_sentry)

          VCR.use_cassette('mpi/add_person/add_person_duplicate') do
            response = subject.add_person_proxy(user)
            exception = response.error.errors.first
            mpi_error_details = response.error.original_body

            expect(response.class).to eq MPI::Responses::AddPersonResponse
            expect(response.status).to eq server_error
            expect(response.mvi_codes).to be_nil
            expect(exception.title).to eq 'Duplicate Keys'
            expect(exception.code).to eq 'MVI_502_DUP'
            expect(exception.status).to eq '502'
            expect(exception.source).to eq MPI::Service

            expect(mpi_error_details).to eq(add_person_error_details)
          end
        end
      end
    end

    context 'with an MVI timeout' do
      let(:base_path) { MPI::Configuration.instance.base_path }

      it 'raises a service error', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI add_person_proxy error: Gateway timeout',
          :warn
        )
        response = subject.add_person_proxy(user)

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
        response = subject.add_person_proxy(user)

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

  describe '.add_person_implicit_search' do
    before do
      expect(MPI::Messages::AddPersonImplicitSearchMessage).to receive(:new).once.and_call_original
    end

    context 'valid request' do
      let(:user) do
        build(:user,
              :loa3,
              ssn: ssn,
              first_name: first_name,
              last_name: last_name,
              address: address,
              birth_date: birth_date,
              email: email,
              idme_uuid: idme_uuid)
      end
      let(:ssn) { 796_111_863 }
      let(:first_name) { 'abraham' }
      let(:last_name) { 'lincoln' }
      let(:address) do
        {
          street: '1600 Pennsylvania Ave',
          city: 'Washington',
          state: 'DC',
          country: 'USA',
          postal_code: '20500'
        }
      end
      let(:birth_date) { '18090212' }
      let(:email) { 'some-email' }
      let(:idme_uuid) { 'b2fab2b5-6af0-45e1-a9e2-394347af91ef' }
      let(:expected_icn) { '1013677101V363970' }
      let(:transaction_id) { '4bae058f5e3cb2c800274633' }
      let(:expected_response_codes) { { icn: expected_icn, transaction_id: transaction_id } }

      it 'creates a new person in MPI' do
        VCR.use_cassette('mpi/add_person/add_person_implicit_search_success') do
          response = subject.add_person_implicit_search(user)
          expect(response.status).to eq('OK')
          expect(response.mvi_codes).to have_deep_attributes(expected_response_codes)
        end
      end

      it 'returns no errors' do
        VCR.use_cassette('mpi/add_person/add_person_implicit_search_success') do
          response = subject.add_person_implicit_search(user)

          expect(response.error).to be_nil
        end
      end
    end

    context 'invalid requests' do
      let(:transaction_id) { '4bae058f5e3cb2c800274634' }

      it 'properly responds if a server error occurs', :aggregate_failures do
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/add_person/add_person_implicit_search_server_error') do
          response = subject.add_person_implicit_search(user)
          exception = response.error.errors.first
          mpi_error_details = response.error.original_body

          expect(response.class).to eq MPI::Responses::AddPersonResponse
          expect(response.status).to eq server_error
          expect(response.mvi_codes).to be_nil
          expect(exception.title).to eq 'Bad Gateway'
          expect(exception.code).to eq 'MVI_502'
          expect(exception.status).to eq '502'
          expect(exception.source).to eq MPI::Service

          expect(mpi_error_details).to eq(add_person_error_details)
        end
      end
    end

    context 'with an MVI timeout' do
      let(:base_path) { MPI::Configuration.instance.base_path }

      it 'raises a service error', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI add_person_implicit error: Gateway timeout',
          :warn
        )
        response = subject.add_person_implicit_search(user)

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
        response = subject.add_person_implicit_search(user)

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

  describe '.update_profile' do
    before do
      expect(MPI::Messages::UpdateProfileMessage).to receive(:new).once.and_call_original
    end

    context 'malformed request' do
      let(:user) do
        build(:user,
              :loa3,
              ssn: ssn,
              first_name: first_name,
              last_name: last_name,
              birth_date: birth_date,
              address: address,
              icn: icn,
              idme_uuid: idme_uuid)
      end
      let(:ssn) { 796_111_863 }
      let(:first_name) { nil }
      let(:last_name) { 'lincoln' }
      let(:birth_date) { '18090212' }
      let(:icn) { '1013677101V363970' }
      let(:address) do
        {
          street: '1600 Pennsylvania Ave',
          city: 'Washington',
          state: 'DC',
          country: 'USA',
          postal_code: '20500'
        }
      end
      let(:idme_uuid) { 'b2fab2b56af045e1a9e2394347af91ef' }
      let(:expected_response_codes) { { idme_uuid: idme_uuid } }
      let(:missing_keys) { [:first_name] }
      let(:expected_sentry_warning) do
        "MVI update_profile request error: Required values missing: #{missing_keys}"
      end

      before { stub_mpi(build(:mvi_profile, given_names: [first_name])) }

      it 'responds with nil' do
        expect(subject.update_profile(user)).to eq(nil)
      end

      it 'logs a message to sentry' do
        expect(subject).to receive(:log_message_to_sentry).with(expected_sentry_warning, :warn)
        subject.update_profile(user)
      end
    end

    context 'valid request' do
      let(:user) do
        build(:user,
              :loa3,
              ssn: ssn,
              first_name: first_name,
              last_name: last_name,
              email: email,
              birth_date: birth_date,
              icn: icn,
              idme_uuid: idme_uuid)
      end
      let(:ssn) { 796_111_863 }
      let(:first_name) { 'abraham' }
      let(:last_name) { 'lincoln' }
      let(:birth_date) { '18090212' }
      let(:icn) { '1013677101V363970' }
      let(:email) { 'some-email' }
      let(:idme_uuid) { 'b2fab2b56af045e1a9e2394347af91ef' }
      let(:transaction_id) { nil }
      let(:expected_response_codes) { { idme_uuid: idme_uuid, transaction_id: transaction_id } }

      it 'successfully updates a correlation profile in MPI' do
        VCR.use_cassette('mpi/update_profile/update_profile_success') do
          response = subject.update_profile(user)
          expect(response.status).to eq('OK')
          expect(response.mvi_codes).to have_deep_attributes(expected_response_codes)
        end
      end

      it 'returns no errors' do
        VCR.use_cassette('mpi/update_profile/update_profile_success') do
          response = subject.update_profile(user)

          expect(response.error).to be_nil
        end
      end
    end

    context 'failed requests' do
      let(:transaction_id) { nil }

      it 'properly responds if a server error occurs', :aggregate_failures do
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/update_profile/update_profile_server_error') do
          response = subject.update_profile(user)
          exception = response.error.errors.first
          mpi_error_details = response.error.original_body

          expect(response.class).to eq MPI::Responses::AddPersonResponse
          expect(response.status).to eq server_error
          expect(response.mvi_codes).to be_nil
          expect(exception.title).to eq 'Bad Gateway'
          expect(exception.code).to eq 'MVI_502'
          expect(exception.status).to eq '502'
          expect(exception.source).to eq MPI::Service

          expect(mpi_error_details).to eq(add_person_error_details)
        end
      end
    end

    context 'invalid requests' do
      let(:code_system) { '2.16.840.1.113883.3.2017.11.6.1' }
      let(:mpi_error_code) { 'PNUPDATE000005' }
      let(:error_texts) do
        ['Enterprise ID 1012592956V095840 passed is not linked to ID e4fd21a4-a677-4118-8c57-1f630cbc2a06',
         'Correlation NOT FOUND']
      end
      let(:error_display_name) { 'ICN-EDI PI Correlation does not exist' }
      let(:id_extension) { '200VGOV-0a8c7539-3490-4c5c-b36f-9df9c16af3a2' }
      let(:transaction_id) { nil }

      it 'properly responds if an invalid request is made', :aggregate_failures do
        expect(subject).to receive(:log_exception_to_sentry)

        VCR.use_cassette('mpi/update_profile/update_profile_failed_no_correlation') do
          response = subject.update_profile(user)
          exception = response.error.errors.first
          mpi_error_details = response.error.original_body

          expect(response.class).to eq MPI::Responses::AddPersonResponse
          expect(response.status).to eq server_error
          expect(response.mvi_codes).to be_nil
          expect(exception.title).to eq 'Bad Gateway'
          expect(exception.code).to eq 'MVI_502'
          expect(exception.status).to eq '502'
          expect(exception.source).to eq MPI::Service

          expect(mpi_error_details).to eq(add_person_error_details)
        end
      end
    end

    context 'with an MVI timeout' do
      let(:base_path) { MPI::Configuration.instance.base_path }

      it 'raises a service error', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(subject).to receive(:log_message_to_sentry).with(
          'MVI update_profile error: Gateway timeout',
          :warn
        )
        response = subject.update_profile(user)

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
        response = subject.update_profile(user)

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
      expect(MPI::Messages::FindProfileByIdentifier).to receive(:new).once.and_call_original
    end

    context 'valid requests' do
      context 'when icn has ^NI^200M^USVHA^P' do
        let(:transaction_id) { '4bae058f5d5c4fa906c85472' }

        before { allow(user).to receive(:mhv_icn).and_return('1008714701V416111^NI^200M^USVHA^P') }

        it 'fetches profile' do
          VCR.use_cassette('mpi/find_candidate/valid_icn_full') do
            profile = mvi_profile
            profile['search_token'] = 'WSDOC1908201553145951848240311'
            expect(Raven).to receive(:tags_context).once.with(mvi_find_profile: 'icn')
            response = subject.find_profile(user)
            expect(response.status).to eq('OK')
            expect(response.profile).to have_deep_attributes(profile)
          end
        end
      end

      context 'when icn has ^NI' do
        let(:transaction_id) { '4bae058f5d5c4fa706c85422' }

        before { allow(user).to receive(:mhv_icn).and_return('1008714701V416111^NI') }

        it 'fetches profile' do
          VCR.use_cassette('mpi/find_candidate/valid_icn_ni_only') do
            profile = mvi_profile
            profile['search_token'] = 'WSDOC1908201553117051423642755'
            response = subject.find_profile(user)
            expect(response.status).to eq('OK')
            expect(response.profile).to have_deep_attributes(profile)
          end
        end
      end

      context 'when icn is just basic icn' do
        let(:transaction_id) { '4bae058f5d5c4fa506c853c2' }

        before { allow(user).to receive(:mhv_icn).and_return('1008714701V416111') }

        it 'fetches profile when icn is just basic icn' do
          VCR.use_cassette('mpi/find_candidate/valid_icn_without_ni') do
            profile = mvi_profile
            profile['search_token'] = 'WSDOC1908201553094460697640189'
            response = subject.find_profile(user)
            expect(response.status).to eq('OK')
            expect(response.profile).to have_deep_attributes(profile)
          end
        end
      end

      context 'when vet360 id exists' do
        before { allow(user).to receive(:mhv_icn).and_return('1008787551V609092^NI^200M^USVHA^P') }

        it 'correctly parses vet360 id', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
          VCR.use_cassette('mpi/find_candidate/valid_vet360_id') do
            response = subject.find_profile(user)
            expect(response.status).to eq('OK')
            expect(response.profile['vet360_id']).to eq('80')
          end
        end
      end

      context 'when historical icns exist' do
        before do
          allow(user).to receive(:mhv_icn).and_return('1008787551V609092^NI^200M^USVHA^P')
          allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')
        end

        it 'fetches historical icns', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
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
      end

      context 'when historical icns do not exist' do
        before do
          allow(user).to receive(:mhv_icn).and_return('1008710003V120120^NI^200M^USVHA^P')
          allow(SecureRandom).to receive(:uuid).and_return('5e819d17-ce9b-4860-929e-f9062836ebd0')
        end

        it 'fetches no historical icns if none exist', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
          VCR.use_cassette('mpi/find_candidate/historical_icns_empty', VCR::MATCH_EVERYTHING) do
            response = subject.find_profile(user, search_type: MPI::Constants::CORRELATION_WITH_ICN_HISTORY)
            expect(response.status).to eq('OK')
            expect(response.profile['historical_icns']).to eq([])
          end
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
      let(:expected_rails_log) { 'MVI Record Not Found' }

      context 'invalid ICN' do
        it 'responds with a SERVER_ERROR', :aggregate_failures do
          allow(user).to receive(:mhv_icn).and_return('invalid-icn-is-here^NI')
          expect(Rails.logger).to receive(:info).with(expected_rails_log)

          VCR.use_cassette('mpi/find_candidate/invalid_icn') do
            response = subject.find_profile(user)

            record_not_found_404_expectations_for(response)
          end
        end
      end

      context 'ICN has no matches' do
        it 'responds with a SERVER_ERROR', :aggregate_failures do
          allow(user).to receive(:mhv_icn).and_return('1008714781V416999')
          expect(Rails.logger).to receive(:info).with(expected_rails_log)

          VCR.use_cassette('mpi/find_candidate/icn_not_found') do
            response = subject.find_profile(user)

            record_not_found_404_expectations_for(response)
          end
        end
      end
    end
  end

  describe '.find_profile with edipi', run_at: 'Wed, 21 Feb 2018 20:19:01 GMT' do
    before do
      expect(MPI::Messages::FindProfileByEdipi).to receive(:new).once.and_call_original
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

  describe '.find_profile with logingov uuid' do
    before do
      stub_mpi(build(:mvi_profile, edipi: nil))
      allow(MPI::Messages::FindProfileByIdentifier).to receive(:new).and_call_original
    end

    context 'valid requests' do
      let(:user_hash) { { logingov_uuid: logingov_uuid, edipi: '', idme_uuid: '' } }
      let(:logingov_uuid) { 'some-logingov-uuid' }
      let(:logingov_identifier) { MPI::Constants::LOGINGOV_IDENTIFIER }
      let(:correlation_identifier) { "#{logingov_uuid}^PN^#{logingov_identifier}^USDVA^A" }
      let(:search_type) { MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA }

      it 'fetches profile when no mhv_icn or edipi exists, but logingov_uuid is present' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          expect(Raven).to receive(:tags_context).once.with(mvi_find_profile: 'logingov')
          expect(MPI::Messages::FindProfileByIdentifier).to receive(:new).with(identifier: correlation_identifier,
                                                                               search_type: search_type)
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile.given_names).to eq(%w[Mitchell G])
          expect(response.profile.family_name).to eq('Jenkins')
          expect(response.profile.full_mvi_ids).to eq(
            [
              '1008714701V416111^NI^200M^USVHA^P',
              '796122306^PI^200BRLS^USVBA^A',
              '9100792239^PI^200CORP^USVBA^A',
              '1008714701^PN^200PROV^USDVA^A',
              '32383600^PI^200CORP^USVBA^L'
            ]
          )
        end
      end
    end
  end

  describe '.find_profile with idme uuid' do
    before do
      stub_mpi(build(:mvi_profile, edipi: nil))
      allow(MPI::Messages::FindProfileByIdentifier).to receive(:new).and_call_original
    end

    context 'valid requests' do
      let(:user_hash) { { idme_uuid: idme_uuid, edipi: '', logingov_uuid: '' } }
      let(:idme_uuid) { 'some-idme-uuid' }
      let(:idme_identifier) { MPI::Constants::IDME_IDENTIFIER }
      let(:correlation_identifier) { "#{idme_uuid}^PN^#{idme_identifier}^USDVA^A" }
      let(:search_type) { MPI::Constants::CORRELATION_WITH_RELATIONSHIP_DATA }

      it 'fetches profile when no mhv_icn or edipi exists, but idme_uuid is present' do
        VCR.use_cassette('mpi/find_candidate/valid') do
          expect(Raven).to receive(:tags_context).once.with(mvi_find_profile: 'idme')
          expect(MPI::Messages::FindProfileByIdentifier).to receive(:new).with(identifier: correlation_identifier,
                                                                               search_type: search_type)
          response = subject.find_profile(user)
          expect(response.status).to eq('OK')
          expect(response.profile.given_names).to eq(%w[Mitchell G])
          expect(response.profile.family_name).to eq('Jenkins')
          expect(response.profile.full_mvi_ids).to eq(
            [
              '1008714701V416111^NI^200M^USVHA^P',
              '796122306^PI^200BRLS^USVBA^A',
              '9100792239^PI^200CORP^USVBA^A',
              '1008714701^PN^200PROV^USDVA^A',
              '32383600^PI^200CORP^USVBA^L'
            ]
          )
        end
      end
    end
  end

  describe '.find_profile without icn' do
    context 'valid request' do
      let(:transaction_id) { '4bae058f5d66cc3801287d52' }

      before do
        expect(MPI::Messages::FindProfileByEdipi).to receive(:new).once.and_call_original
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
        let(:transaction_id) { '4bae058f5d66d28b011bf351' }

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
      let(:id_extension) { '200VGOV-2c3c0c78-5e44-4ad2-b542-11388c3e45cd' }
      let(:error_texts) { ['MVI[S]:INVALID REQUEST'] }
      let(:expected_rails_log) { 'MVI Record Not Found' }

      it 'raises a invalid request error', :aggregate_failures do
        invalid_xml = File.read('spec/support/mpi/find_candidate_invalid_request.xml')
        allow_any_instance_of(MPI::Service).to receive(:create_profile_message).and_return(invalid_xml)
        expect(Rails.logger).to receive(:info).with(expected_rails_log)

        VCR.use_cassette('mpi/find_candidate/invalid') do
          response = subject.find_profile(user)
          record_not_found_404_expectations_for(response)
        end
      end
    end

    context 'when a MVI internal system problem response is returned' do
      let(:body) { File.read('spec/support/mpi/find_candidate_ar_code_database_error_response.xml') }
      let(:ack_detail_code) { 'AR' }
      let(:id_extension) { 'MCID-12345' }
      let(:error_texts) { ['Environment Database Error'] }

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
        expect(MPI::Messages::FindProfileByEdipi).to receive(:new).once.and_call_original
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
        expect(MPI::Messages::FindProfileByEdipi).to receive(:new).once.and_call_original
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
        expect(MPI::Messages::FindProfileByEdipi).to receive(:new).once.and_call_original
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

  describe '.add_person_proxy monitoring' do
    context 'with a successful request' do
      let(:user) { build(:user_with_no_ids) }

      it 'increments add_person_proxy total' do
        allow(StatsD).to receive(:increment)
        VCR.use_cassette('mpi/add_person/add_person_success') do
          subject.add_person_proxy(user)
        end
        expect(StatsD).to have_received(:increment).with('api.mvi.add_person_proxy.total')
      end
    end

    context 'with an unsuccessful request' do
      it 'increments add_person_proxy fail and total', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(StatsD).to receive(:increment).once.with(
          'api.mvi.add_person_proxy.fail', tags: ['error:CommonExceptionsGatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.mvi.add_person_proxy.total')
        response = subject.add_person_proxy(user)

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

  describe '.add_person_implicit_search monitoring' do
    context 'with a successful request' do
      let(:user) { build(:user_with_no_ids) }

      it 'increments add_person_implicit_search total' do
        allow(StatsD).to receive(:increment)
        VCR.use_cassette('mpi/add_person/add_person_implicit_search_success') do
          subject.add_person_implicit_search(user)
        end
        expect(StatsD).to have_received(:increment).with('api.mvi.add_person_implicit_search.total')
      end
    end

    context 'with an unsuccessful request' do
      it 'increments add_person_implicit_search fail and total', :aggregate_failures do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(StatsD).to receive(:increment).once.with(
          'api.mvi.add_person_implicit_search.fail', tags: ['error:CommonExceptionsGatewayTimeout']
        )
        expect(StatsD).to receive(:increment).once.with('api.mvi.add_person_implicit_search.total')
        response = subject.add_person_implicit_search(user)

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
  mpi_error_details = response.error.original_body

  expect(response.class).to eq MPI::Responses::FindProfileResponse
  expect(response.status).to eq server_error
  expect(response.profile).to be_nil
  expect(exception.title).to eq 'Bad Gateway'
  expect(exception.code).to eq 'MVI_502'
  expect(exception.status).to eq '502'
  expect(exception.source).to eq MPI::Service
  expect(mpi_error_details).to eq find_profile_error_details
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
