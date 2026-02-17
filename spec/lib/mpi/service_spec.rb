# frozen_string_literal: true

require 'rails_helper'
require 'mpi/service'

describe MPI::Service do
  let(:mpi_service) { MPI::Service.new }
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
  let(:not_found) { :not_found }
  let(:server_error) { :server_error }
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
      transaction_id:,
      error_details: { ack_detail_code:,
                       id_extension:,
                       error_texts: } }
  end
  let(:find_profile_error_details) do
    { error_details: { ack_detail_code:,
                       id_extension:,
                       error_texts: } }
  end

  let(:mpi_profile) do
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
      icn_with_aaid:,
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
      transaction_id:
    )
  end

  before { allow(StatsD).to receive(:increment) }

  shared_examples 'add person error response' do
    it 'returns an add person response with server error status' do
      expect(subject.status).to eq(:server_error)
    end

    it 'returns an add person response with no parsed codes' do
      expect(subject.parsed_codes).to be_nil
    end

    it 'returns an add person response with expected error message' do
      expect(subject.error.message).to eq(expected_error_message)
    end
  end

  shared_examples 'add person success response' do
    it 'returns response object with status' do
      expect(subject.status).to eq(:ok)
    end

    it 'returns response object with parsed codes' do
      expect(subject.parsed_codes).to have_deep_attributes(parsed_response)
    end

    it 'increments total statsd' do
      expect(StatsD).to receive(:increment).with("api.mvi.#{statsd_caller}.total")
      subject
    end
  end

  shared_examples 'connection add person error response' do
    it_behaves_like 'add person error response'

    it 'increments statsd failure' do
      expect(StatsD).to receive(:increment).with("api.mvi.#{statsd_caller}.fail",
                                                 tags: ["error:#{expected_error.to_s.gsub(':', '')}"])
      expect(StatsD).to receive(:increment).with("api.mvi.#{statsd_caller}.total")
      subject
    end
  end

  describe '#add_person_proxy' do
    subject do
      mpi_service.add_person_proxy(last_name:,
                                   ssn:,
                                   birth_date:,
                                   icn:,
                                   edipi:,
                                   search_token:,
                                   first_name:,
                                   as_agent:)
    end

    let(:statsd_caller) { 'add_person_proxy' }
    let(:ssn) { 796_111_863 }
    let(:first_name) { 'abraham' }
    let(:last_name) { 'lincoln' }
    let(:birth_date) { '18090212' }
    let(:edipi) { 'some-edipi' }
    let(:search_token) { 'WSDOC2002071538432741110027956' }
    let(:icn) { '1013062086V794840' }
    let(:as_agent) { false }

    context 'valid requests' do
      context 'when current user has neither birls_id or participant_id' do
        let(:user) { build(:user_with_no_ids) }
        let(:parsed_response) do
          {
            birls_id: '111985523',
            participant_id: '32397028',
            transaction_id: '4bae058f5e3db50000682d01'
          }
        end

        before { VCR.insert_cassette('mpi/add_person/add_person_success') }

        after { VCR.eject_cassette('mpi/add_person/add_person_success') }

        it_behaves_like 'add person success response'

        context 'when as_agent is true' do
          let(:as_agent) { true }

          before { VCR.insert_cassette('mpi/add_person/add_person_as_agent_success') }

          after { VCR.eject_cassette('mpi/add_person/add_person_as_agent_success') }

          it_behaves_like 'add person success response'
        end
      end

      context 'when user has both birls_id and participant_id' do
        let(:user) { build(:user, :loa3) }

        let(:parsed_response) do
          {
            birls_id: '796104437',
            participant_id: '13367440',
            transaction_id: '4bae058f5e3cb2c800274633',
            other: [{ codeSystem: MPI::Constants::VA_ROOT_OID, code: 'WRN206', displayName: 'Existing Key Identifier' }]
          }
        end

        before { VCR.insert_cassette('mpi/add_person/add_person_already_exists') }

        after { VCR.eject_cassette('mpi/add_person/add_person_already_exists') }

        it_behaves_like 'add person success response'

        context 'when as_agent is true' do
          let(:as_agent) { true }

          before { VCR.insert_cassette('mpi/add_person/add_person_as_agent_already_exists') }

          after { VCR.eject_cassette('mpi/add_person/add_person_as_agent_already_exists') }

          it_behaves_like 'add person success response'
        end
      end
    end

    context 'invalid requests' do
      let(:add_person_error_details) do
        { other: [{ codeSystem: code_system, code: mpi_error_code, displayName: error_display_name }],
          transaction_id:,
          error_details: { ack_detail_code:, id_extension:, error_texts: } }
      end
      let(:transaction_id) { 'some-transaction-id' }
      let(:code_system) { 'some-code-system' }
      let(:mpi_error_code) { 'some-mpi-error-code' }
      let(:ack_detail_code) { 'some-ack-detail-code' }
      let(:error_texts) { ['some-error-texts'] }
      let(:error_display_name) { 'some-error-display-name' }
      let(:id_extension) { 'some-id-extension' }

      context 'when response includes invalid request error' do
        let(:transaction_id) { '4bae058f5e3cb6080028a411' }
        let(:code_system) { '2.16.840.1.113883.5.1100' }
        let(:mpi_error_code) { 'INTERR' }
        let(:ack_detail_code) { 'AE' }
        let(:error_texts) { ['Internal System Error'] }
        let(:error_display_name) { 'Internal System Error' }
        let(:id_extension) { '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a' }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/add_person/add_person_invalid_request') }

        after { VCR.eject_cassette('mpi/add_person/add_person_invalid_request') }

        it_behaves_like 'add person error response'
      end

      context 'when response includes internal error' do
        let(:transaction_id) { '4bae058f5e3cb6080028a411' }
        let(:code_system) { '2.16.840.1.113883.5.1100' }
        let(:mpi_error_code) { 'INTERR' }
        let(:ack_detail_code) { 'AR' }
        let(:error_texts) { ['Internal System Error'] }
        let(:error_display_name) { 'Internal System Error' }
        let(:id_extension) { '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a' }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/add_person/add_person_internal_error_request') }

        after { VCR.eject_cassette('mpi/add_person/add_person_internal_error_request') }

        it_behaves_like 'add person error response'
      end

      context 'when response includes duplicate error' do
        let(:transaction_id) { '4bae058f5e3cb4a300385c30' }
        let(:ack_detail_code) { 'AE' }
        let(:code_system) { '2.16.840.1.113883.5.4' }
        let(:mpi_error_code) { 'Key205' }
        let(:error_texts) { ['identified as a duplicate'] }
        let(:error_display_name) { 'Duplicate Key Identifier' }
        let(:id_extension) { '200VGOV-ac8c9bae-cd12-4609-811c-00bde47373bf' }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/add_person/add_person_duplicate') }

        after { VCR.eject_cassette('mpi/add_person/add_person_duplicate') }

        it_behaves_like 'add person error response'
      end

      context 'when request fails due to gateway timeout' do
        let(:expected_error) { Common::Exceptions::GatewayTimeout }
        let(:expected_error_message) { expected_error.new.message }

        before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails due to client error' do
        let(:expected_error) { Common::Client::Errors::ClientError }
        let(:expected_error_message) { expected_error.new.message }

        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Common::Client::Errors::ClientError)
        end

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails due to connection failed' do
        let(:expected_error) { Common::Client::Errors::ClientError }
        let(:expected_error_message) { Faraday::ConnectionFailed.new(faraday_error_message).message }
        let(:faraday_error_message) { 'some-message' }

        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed,
                                                                                 faraday_error_message)
        end

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails to breakers outage' do
        let(:current_time) { Time.zone.now }
        let(:expected_error) { Breakers::OutageException }
        let(:expected_error_message) { "Outage detected on MVI beginning at #{current_time.to_i}" }

        before do
          Timecop.freeze
          MPI::Configuration.instance.breakers_service.begin_forced_outage!
        end

        after { Timecop.return }

        it_behaves_like 'connection add person error response'
      end
    end
  end

  describe '#add_person_implicit_search' do
    subject do
      mpi_service.add_person_implicit_search(last_name:,
                                             ssn:,
                                             birth_date:,
                                             email:,
                                             address:,
                                             idme_uuid:,
                                             logingov_uuid:,
                                             first_name:)
    end

    let(:statsd_caller) { 'add_person_implicit_search' }
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
    let(:logingov_uuid) { nil }

    context 'valid request' do
      let(:expected_icn) { '1013677101V363970' }
      let(:transaction_id) { '4bae058f5e3cb2c800274633' }
      let(:parsed_response) { { icn: expected_icn, transaction_id: } }

      before { VCR.insert_cassette('mpi/add_person/add_person_implicit_search_success') }

      after { VCR.eject_cassette('mpi/add_person/add_person_implicit_search_success') }

      it_behaves_like 'add person success response'
    end

    context 'invalid requests' do
      let(:add_person_error_details) do
        { other: [{ codeSystem: code_system, code: mpi_error_code, displayName: error_display_name }],
          transaction_id:,
          error_details: { ack_detail_code:, id_extension:, error_texts: } }
      end
      let(:transaction_id) { 'some-transaction-id' }
      let(:code_system) { 'some-code-system' }
      let(:mpi_error_code) { 'some-mpi-error-code' }
      let(:ack_detail_code) { 'some-ack-detail-code' }
      let(:error_texts) { ['some-error-texts'] }
      let(:error_display_name) { 'some-error-display-name' }
      let(:id_extension) { 'some-id-extension' }

      context 'when response includes invalid request error' do
        let(:code_system) { '2.16.840.1.113883.5.1100' }
        let(:mpi_error_code) { 'INTERR' }
        let(:ack_detail_code) { 'AE' }
        let(:error_texts) { ['Internal System Error'] }
        let(:error_display_name) { 'Internal System Error' }
        let(:id_extension) { '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a' }
        let(:transaction_id) { '4bae058f5e3cb2c800274634' }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/add_person/add_person_implicit_search_server_error') }

        after { VCR.eject_cassette('mpi/add_person/add_person_implicit_search_server_error') }

        it_behaves_like 'add person error response'
      end

      context 'when response includes internal error' do
        let(:transaction_id) { '4bae058f5e3cb6080028a411' }
        let(:code_system) { '2.16.840.1.113883.5.1100' }
        let(:mpi_error_code) { 'INTERR' }
        let(:ack_detail_code) { 'AR' }
        let(:error_texts) { ['Internal System Error'] }
        let(:error_display_name) { 'Internal System Error' }
        let(:id_extension) { '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a' }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/add_person/add_person_internal_error_request') }

        after { VCR.eject_cassette('mpi/add_person/add_person_internal_error_request') }

        it_behaves_like 'add person error response'
      end

      context 'when response includes duplicate error' do
        let(:transaction_id) { '4bae058f5e3cb4a300385c30' }
        let(:ack_detail_code) { 'AE' }
        let(:code_system) { '2.16.840.1.113883.5.4' }
        let(:mpi_error_code) { 'Key205' }
        let(:error_texts) { ['identified as a duplicate'] }
        let(:error_display_name) { 'Duplicate Key Identifier' }
        let(:id_extension) { '200VGOV-ac8c9bae-cd12-4609-811c-00bde47373bf' }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/add_person/add_person_duplicate') }

        after { VCR.eject_cassette('mpi/add_person/add_person_duplicate') }

        it_behaves_like 'add person error response'
      end

      context 'when request fails due to gateway timeout' do
        let(:expected_error) { Common::Exceptions::GatewayTimeout }
        let(:expected_error_message) { expected_error.new.message }

        before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails due to client error' do
        let(:expected_error) { Common::Client::Errors::ClientError }
        let(:expected_error_message) { expected_error.new.message }

        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Common::Client::Errors::ClientError)
        end

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails due to connection failed' do
        let(:expected_error) { Common::Client::Errors::ClientError }
        let(:expected_error_message) { Faraday::ConnectionFailed.new(faraday_error_message).message }
        let(:faraday_error_message) { 'some-message' }

        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed,
                                                                                 faraday_error_message)
        end

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails to breakers outage' do
        let(:current_time) { Time.zone.now }
        let(:expected_error) { Breakers::OutageException }
        let(:expected_error_message) { "Outage detected on MVI beginning at #{current_time.to_i}" }

        before do
          Timecop.freeze
          MPI::Configuration.instance.breakers_service.begin_forced_outage!
        end

        after { Timecop.return }

        it_behaves_like 'connection add person error response'
      end
    end
  end

  describe '#update_profile' do
    subject do
      mpi_service.update_profile(last_name:,
                                 ssn:,
                                 birth_date:,
                                 icn:,
                                 email:,
                                 address:,
                                 idme_uuid:,
                                 logingov_uuid:,
                                 edipi:,
                                 first_name:)
    end

    let(:statsd_caller) { 'update_profile' }
    let(:last_name) { 'some-last-name' }
    let(:ssn) { 'some-ssn' }
    let(:birth_date) { '19800202' }
    let(:icn) { 'some-icn' }
    let(:email) { 'some-email' }
    let(:address) do
      {
        street: 'some-street',
        state: 'some-state',
        city: 'some-city',
        postal_code: 'some-postal-code',
        country: 'some-country'
      }
    end
    let(:idme_uuid) { 'some-idme-uuid' }
    let(:logingov_uuid) { 'some-logingov-uuid' }
    let(:edipi) { 'some-edipi' }
    let(:first_name) { 'some-first-name' }

    context 'malformed request' do
      let(:last_name) { nil }
      let(:missing_keys) { [:last_name] }
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { "Required values missing: #{missing_keys}" }

      it 'raises a required values missing error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'valid request' do
      let(:transaction_id) { nil }
      let(:idme_uuid) { 'b2fab2b56af045e1a9e2394347af91ef' }
      let(:parsed_response) { { idme_uuid:, transaction_id: } }

      before { VCR.insert_cassette('mpi/update_profile/update_profile_success') }

      after { VCR.eject_cassette('mpi/update_profile/update_profile_success') }

      it_behaves_like 'add person success response'
    end

    context 'invalid requests' do
      let(:add_person_error_details) do
        { other: [{ codeSystem: code_system, code: mpi_error_code, displayName: error_display_name }],
          transaction_id:,
          error_details: { ack_detail_code:, id_extension:, error_texts: } }
      end
      let(:transaction_id) { 'some-transaction-id' }
      let(:code_system) { 'some-code-system' }
      let(:mpi_error_code) { 'some-mpi-error-code' }
      let(:ack_detail_code) { 'some-ack-detail-code' }
      let(:error_texts) { ['some-error-texts'] }
      let(:error_display_name) { 'some-error-display-name' }
      let(:id_extension) { 'some-id-extension' }

      context 'when response includes invalid request error' do
        let(:code_system) { '2.16.840.1.113883.5.1100' }
        let(:mpi_error_code) { 'INTERR' }
        let(:ack_detail_code) { 'AE' }
        let(:error_texts) { ['Internal System Error'] }
        let(:error_display_name) { 'Internal System Error' }
        let(:id_extension) { '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a' }
        let(:transaction_id) { nil }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/update_profile/update_profile_server_error') }

        after { VCR.eject_cassette('mpi/update_profile/update_profile_server_error') }

        it_behaves_like 'add person error response'
      end

      context 'when response includes internal error' do
        let(:transaction_id) { '4bae058f5e3cb6080028a411' }
        let(:code_system) { '2.16.840.1.113883.5.1100' }
        let(:mpi_error_code) { 'INTERR' }
        let(:ack_detail_code) { 'AR' }
        let(:error_texts) { ['Internal System Error'] }
        let(:error_display_name) { 'Internal System Error' }
        let(:id_extension) { '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a' }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/add_person/add_person_internal_error_request') }

        after { VCR.eject_cassette('mpi/add_person/add_person_internal_error_request') }

        it_behaves_like 'add person error response'
      end

      context 'when response includes correlation not found error' do
        let(:code_system) { '2.16.840.1.113883.3.2017.11.6.1' }
        let(:mpi_error_code) { 'PNUPDATE000005' }
        let(:error_texts) do
          ['Enterprise ID 1012592956V095840 passed is not linked to ID e4fd21a4-a677-4118-8c57-1f630cbc2a06',
           'Correlation NOT FOUND']
        end
        let(:error_display_name) { 'ICN-EDI PI Correlation does not exist' }
        let(:id_extension) { '200VGOV-0a8c7539-3490-4c5c-b36f-9df9c16af3a2' }
        let(:transaction_id) { nil }
        let(:ack_detail_code) { 'AE' }
        let(:expected_error_message) { add_person_error_details.to_s }

        before { VCR.insert_cassette('mpi/update_profile/update_profile_failed_no_correlation') }

        after { VCR.eject_cassette('mpi/update_profile/update_profile_failed_no_correlation') }

        it_behaves_like 'add person error response'
      end

      context 'when request fails due to gateway timeout' do
        let(:expected_error) { Common::Exceptions::GatewayTimeout }
        let(:expected_error_message) { expected_error.new.message }

        before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails due to client error' do
        let(:expected_error) { Common::Client::Errors::ClientError }
        let(:expected_error_message) { expected_error.new.message }

        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Common::Client::Errors::ClientError)
        end

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails due to connection failed' do
        let(:expected_error) { Common::Client::Errors::ClientError }
        let(:expected_error_message) { Faraday::ConnectionFailed.new(faraday_error_message).message }
        let(:faraday_error_message) { 'some-message' }

        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed,
                                                                                 faraday_error_message)
        end

        it_behaves_like 'connection add person error response'
      end

      context 'when request fails to breakers outage' do
        let(:current_time) { Time.zone.now }
        let(:expected_error) { Breakers::OutageException }
        let(:expected_error_message) { "Outage detected on MVI beginning at #{current_time.to_i}" }

        before do
          Timecop.freeze
          MPI::Configuration.instance.breakers_service.begin_forced_outage!
        end

        after { Timecop.return }

        it_behaves_like 'connection add person error response'
      end
    end
  end

  shared_examples 'find profile success response' do
    let(:transaction_id) { '4bae058f5d5c4fa906c85472' }
    let(:identifier_type) { MPI::Constants::ICN }
    let(:expected_icn) { '1008714701V416111' }
    let(:parsed_response) { { transaction_id: } }

    before { VCR.insert_cassette('mpi/find_candidate/valid_icn_full') }

    after { VCR.eject_cassette('mpi/find_candidate/valid_icn_full') }

    it 'returns response object with status' do
      expect(subject.status).to eq(:ok)
    end

    it 'returns response object with expected attributes' do
      expect(subject.profile.icn).to eq(expected_icn)
      expect(subject.profile.transaction_id).to eq(transaction_id)
    end

    it 'increments total statsd' do
      expect(StatsD).to receive(:increment).with("api.mvi.#{statsd_caller}.total")
      subject
    end
  end

  shared_examples 'find profile error response' do
    it 'returns a find profile response with server error status' do
      expect(subject.status).to eq(expected_status)
    end

    it 'returns a find profile response with no profile' do
      expect(subject.profile).to be_nil
    end

    it 'returns a find profile response with expected error message' do
      expect(subject.error.message).to eq(expected_error_message)
    end
  end

  shared_examples 'connection find profile error response' do
    let(:expected_status) { :server_error }

    it_behaves_like 'find profile error response'

    it 'increments statsd failure' do
      expect(StatsD).to receive(:increment).with("api.mvi.#{statsd_caller}.fail",
                                                 tags: ["error:#{expected_error.to_s.gsub(':', '')}"])
      expect(StatsD).to receive(:increment).with("api.mvi.#{statsd_caller}.total")
      subject
    end
  end

  shared_examples 'find profile invalid requests' do
    let(:find_profile_error_details) do
      { error_details: { ack_detail_code:,
                         id_extension:,
                         transaction_id:,
                         error_texts: } }
    end
    let(:transaction_id) { 'some-transaction-id' }
    let(:ack_detail_code) { 'some-ack-detail-code' }
    let(:error_texts) { ['some-error-texts'] }
    let(:id_extension) { 'some-id-extension' }

    context 'when response includes invalid request error' do
      let(:ack_detail_code) { 'AE' }
      let(:error_texts) { ['MVI[S]:INVALID REQUEST'] }
      let(:id_extension) { '200VGOV-2c3c0c78-5e44-4ad2-b542-11388c3e45cd' }
      let(:transaction_id) { '4bae058f5d713bb4016e2a43' }
      let(:expected_error_message) { find_profile_error_details.to_s }
      let(:expected_status) { :not_found }

      before { VCR.insert_cassette('mpi/find_candidate/invalid') }

      after { VCR.eject_cassette('mpi/find_candidate/invalid') }

      it_behaves_like 'find profile error response'
    end

    context 'when response includes failed request' do
      let(:ack_detail_code) { 'AR' }
      let(:error_texts) { ['Environment Database Error'] }
      let(:id_extension) { 'MCID-12345' }
      let(:transaction_id) { 'f8ba53155d67e14c02239302' }
      let(:expected_error_message) { find_profile_error_details.to_s }
      let(:expected_status) { :server_error }

      before { VCR.insert_cassette('mpi/find_candidate/find_profile_internal_error') }

      after { VCR.eject_cassette('mpi/find_candidate/find_profile_internal_error') }

      it_behaves_like 'find profile error response'
    end

    context 'when response includes multiple match error' do
      let(:ack_detail_code) { 'AE' }
      let(:error_texts) { ['Multiple Matches Found', 'Multiple MatchesFound'] }
      let(:id_extension) { '200VGOV-03b2801a-3005-4dcc-9a3c-7e3e4c0d5293' }
      let(:transaction_id) { 'f8ba53155d67e14c02239302' }
      let(:expected_error_message) { find_profile_error_details.to_s }
      let(:expected_status) { :not_found }

      before { VCR.insert_cassette('mpi/find_candidate/failure_multiple_matches') }

      after { VCR.eject_cassette('mpi/find_candidate/failure_multiple_matches') }

      it_behaves_like 'find profile error response'
    end

    context 'when request fails due to gateway timeout' do
      let(:expected_error) { Common::Exceptions::GatewayTimeout }
      let(:expected_error_message) { expected_error.new.message }

      before { allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError) }

      it_behaves_like 'connection find profile error response'
    end

    context 'when request fails due to client error' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) { expected_error.new.message }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Common::Client::Errors::ClientError)
      end

      it_behaves_like 'connection find profile error response'
    end

    context 'when request fails due to connection failed' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) { Faraday::ConnectionFailed.new(faraday_error_message).message }
      let(:faraday_error_message) { 'some-message' }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::ConnectionFailed,
                                                                               faraday_error_message)
      end

      it_behaves_like 'connection find profile error response'
    end

    context 'when request fails to breakers outage' do
      let(:current_time) { Time.zone.now }
      let(:expected_error) { Breakers::OutageException }
      let(:expected_error_message) { "Outage detected on MVI beginning at #{current_time.to_i}" }

      before do
        Timecop.freeze
        MPI::Configuration.instance.breakers_service.begin_forced_outage!
      end

      after { Timecop.return }

      it_behaves_like 'connection find profile error response'
    end
  end

  describe '#find_profile_by_identifier' do
    subject do
      mpi_service.find_profile_by_identifier(identifier:,
                                             identifier_type:,
                                             search_type:,
                                             view_type:)
    end

    let(:statsd_caller) { 'find_profile_by_identifier' }
    let(:identifier) { 'some-identifier' }
    let(:identifier_type) { MPI::Constants::QUERY_IDENTIFIERS.first }
    let(:search_type) { 'some-search-type' }
    let(:view_type) { MPI::Constants::VIEW_TYPES.first }

    context 'malformed request' do
      let(:expected_error) { MPI::Errors::ArgumentError }

      context 'when identifier type is not supported' do
        let(:identifier_type) { 'unsupported-identifier-type' }
        let(:expected_error_message) { "Identifier type is not supported, identifier_type=#{identifier_type}" }

        it 'raises a identifier type not supported error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'when view type is not supported' do
        let(:view_type) { 'unsupported-view-type' }
        let(:expected_error_message) { "View type is not supported, view_type=#{view_type}" }

        it 'raises a view type not supported error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'valid request' do
      it_behaves_like 'find profile success response'
    end

    context 'invalid requests' do
      it_behaves_like 'find profile invalid requests'
    end
  end

  describe '#find_profile_by_edipi' do
    subject { mpi_service.find_profile_by_edipi(edipi:, search_type:) }

    let(:statsd_caller) { 'find_profile_by_edipi' }
    let(:edipi) { 'some-edipi' }
    let(:search_type) { 'some-search-type' }

    context 'valid request' do
      it_behaves_like 'find profile success response'
    end

    context 'invalid requests' do
      it_behaves_like 'find profile invalid requests'
    end
  end

  describe '#find_profile_by_facility' do
    subject { mpi_service.find_profile_by_facility(facility_id:, vista_id:, search_type:) }

    let(:statsd_caller) { 'find_profile_by_facility' }
    let(:facility_id) { 'some-facility-id' }
    let(:vista_id) { 'some-vista-id' }
    let(:search_type) { 'some-search-type' }

    context 'valid request' do
      it_behaves_like 'find profile success response'
    end

    context 'invalid requests' do
      it_behaves_like 'find profile invalid requests'
    end
  end

  describe '#find_profile_by_attributes_with_orch_search' do
    subject do
      mpi_service.find_profile_by_attributes_with_orch_search(first_name:,
                                                              last_name:,
                                                              birth_date:,
                                                              ssn:,
                                                              edipi:)
    end

    let(:statsd_caller) { 'find_profile_by_attributes_with_orch_search' }
    let(:first_name) { 'some-first-name' }
    let(:last_name) { 'some-last-name' }
    let(:birth_date) { '19700101' }
    let(:ssn) { 'some-ssn' }
    let(:edipi) { 'some-edipi' }

    context 'malformed request' do
      let(:edipi) { nil }
      let(:missing_keys) { [:edipi] }
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { "Required values missing: #{missing_keys}" }

      it 'raises a required values missing error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'valid request' do
      it_behaves_like 'find profile success response'
    end

    context 'invalid requests' do
      it_behaves_like 'find profile invalid requests'
    end
  end

  describe '#find_profile_by_attributes' do
    subject do
      mpi_service.find_profile_by_attributes(first_name:,
                                             last_name:,
                                             birth_date:,
                                             ssn:,
                                             search_type:)
    end

    let(:statsd_caller) { 'find_profile_by_attributes' }
    let(:first_name) { 'some-first-name' }
    let(:last_name) { 'some-last-name' }
    let(:birth_date) { '19700101' }
    let(:ssn) { 'some-ssn' }
    let(:search_type) { 'some-search-type' }

    context 'malformed request' do
      let(:first_name) { nil }
      let(:missing_keys) { [:first_name] }
      let(:expected_error) { MPI::Errors::ArgumentError }
      let(:expected_error_message) { "Required values missing: #{missing_keys}" }

      it 'raises a required values missing error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'valid request' do
      it_behaves_like 'find profile success response'
    end

    context 'invalid requests' do
      it_behaves_like 'find profile invalid requests'
    end
  end
end
