# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/profile_parser'

describe MPI::Responses::ProfileParser do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:parser) { MPI::Responses::ProfileParser.new(faraday_response) }

  context 'given a valid response' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_response.xml')) }

    before do
      allow(faraday_response).to receive(:body) { body }
    end

    describe '#failed_or_invalid?' do
      it 'returns false' do
        expect(parser).not_to be_failed_or_invalid
      end
    end

    describe '#parse' do
      let(:mvi_profile) do
        build(
          :mpi_profile_response,
          :address_austin,
          birls_id: nil,
          birls_ids: [],
          sec_id: nil,
          historical_icns: nil,
          search_token: 'WSDOC1609131753362231779394902'
        )
      end

      it 'returns a MviProfile with the parsed attributes' do
        expect(parser.parse).to have_deep_attributes(mvi_profile)
      end

      context 'when name parsing fails' do
        let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_missing_name_response.xml')) }
        let(:mvi_profile) do
          build(
            :mpi_profile_response,
            :address_austin,
            family_name: nil,
            given_names: nil,
            suffix: nil,
            birls_id: nil,
            birls_ids: [],
            sec_id: nil,
            historical_icns: nil,
            search_token: 'WSDOC1609131753362231779394902'
          )
        end

        it 'sets the names to false' do
          expect(parser.parse).to have_deep_attributes(mvi_profile)
        end
      end

      context 'with a missing address, invalid edipi, and invalid participant id' do
        let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_response_nil_address.xml')) }
        let(:mvi_profile) do
          build(
            :mpi_profile_response,
            address: nil,
            birls_id: nil,
            birls_ids: [],
            sec_id: nil,
            historical_icns: nil,
            vet360_id: nil,
            edipi: nil,
            participant_id: nil,
            full_mvi_ids: [
              '1000123456V123456^NI^200M^USVHA^P',
              '12345^PI^516^USVHA^PCE',
              '2^PI^553^USVHA^PCE',
              '12345^PI^200HD^USVHA^A',
              'TKIP123456^PI^200IP^USVHA^A',
              '123456^PI^200MHV^USVHA^A',
              'UNK^NI^200DOD^USDOD^A',
              'UNK^PI^200CORP^USVBA^A'
            ],
            search_token: 'WSDOC1609131753362231779394902'
          )
        end

        it 'sets the address to nil' do
          expect(parser.parse).to have_deep_attributes(mvi_profile)
        end
      end

      context 'with no middle name, missing and alternate correlation ids, multiple other_ids' do
        let(:icn_with_aaid) { '1008714701V416111^NI^200M^USVHA' }
        let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_missing_attrs_response.xml')) }
        let(:mvi_profile) do
          build(
            :mpi_profile_response,
            :missing_attrs,
            :address_austin,
            birls_id: '796122306',
            birls_ids: ['796122306'],
            sec_id: '1008714701',
            historical_icns: nil,
            mhv_ids: ['1100792239'],
            active_mhv_ids: ['1100792239'],
            icn_with_aaid: icn_with_aaid,
            full_mvi_ids: [
              '1008714701V416111^NI^200M^USVHA^P',
              '796122306^PI^200BRLS^USVBA^A',
              '9100792239^PI^200CORP^USVBA^A',
              '1008714701^PN^200PROV^USDVA^A',
              '1100792239^PI^200MHS^USVHA^A'
            ],
            search_token: 'WSDOC1908201553145951848240311'
          )
        end

        it 'filters with only first name and retrieve correct MHV id' do
          expect(parser.parse).to have_deep_attributes(mvi_profile)
        end
      end
    end
  end

  context 'given a valid response with relationship information' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_with_relationship_response.xml')) }

    before do
      allow(faraday_response).to receive(:body) { body }
    end

    describe '#parse' do
      let(:mvi_profile) do
        build(
          :mpi_profile_response,
          :with_relationship,
          :with_nil_address,
          given_names: %w[Randy],
          family_name: 'Little',
          suffix: 'Jr',
          gender: 'M',
          birth_date: '19901004',
          ssn: '999123456',
          home_phone: '1112223333',
          icn: nil,
          icn_with_aaid: nil,
          historical_icns: [],
          full_mvi_ids: [],
          sec_id: nil,
          vet360_id: nil,
          mhv_ids: [],
          active_mhv_ids: [],
          vha_facility_ids: [],
          cerner_id: nil,
          cerner_facility_ids: [],
          edipi: nil,
          participant_id: nil,
          birls_id: nil,
          birls_ids: [],
          search_token: 'WSDOC2005221733165441605720989',
          person_type_code: 'Dependent',
          relationships: [mpi_profile_relationship_component]
        )
      end

      let(:mpi_profile_relationship_component) do
        build(
          :mpi_profile_relationship,
          person_type_code: [],
          given_names: %w[Mark],
          family_name: 'Webb',
          suffix: 'Jr',
          gender: 'M',
          birth_date: '19501004',
          ssn: '796104437',
          address: nil,
          home_phone: 'mailto:Daniel.Rocha@va.gov',
          full_mvi_ids: [
            '1008709396V637156^NI^200M^USVHA^P',
            '1013590059^NI^200DOD^USDOD^A',
            '0001740097^PN^200PROV^USDVA^A',
            '796104437^PI^200BRLS^USVBA^A',
            '13367440^PI^200CORP^USVBA^A',
            '0000027647^PN^200PROV^USDVA^A',
            '0000027648^PN^200PROV^USDVA^A',
            '1babbd957ca14e44880a534b65bb0ed4^PN^200VIDM^USDVA^A',
            '4795335^PI^200MH^USVHA^A',
            '7909^PI^200VETS^USDVA^A',
            '6400bbf301eb4e6e95ccea7693eced6f^PN^200VIDM^USDVA^A'
          ],
          icn: '1008709396V637156',
          icn_with_aaid: '1008709396V637156^NI^200M^USVHA',
          mhv_ids: ['4795335'],
          active_mhv_ids: ['4795335'],
          vha_facility_ids: %w[200MH],
          edipi: '1013590059',
          participant_id: '13367440',
          birls_id: '796104437',
          birls_ids: ['796104437'],
          sec_id: '0001740097',
          vet360_id: '7909',
          historical_icns: [],
          cerner_id: nil,
          cerner_facility_ids: []
        )
      end

      it 'returns a MviProfile with the parsed attributes' do
        expect(parser.parse).to have_deep_attributes(mvi_profile)
      end
    end
  end

  context 'with no subject element' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_no_subject_response.xml')) }
    let(:mvi_profile) { build(:mpi_profile_response, :missing_attrs) }

    describe '#parse' do
      it 'return nil if the response includes no suject element' do
        allow(faraday_response).to receive(:body) { body }
        expect(parser.parse).to be_nil
      end
    end
  end

  context 'given an invalid response' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_invalid_response.xml')) }

    describe '#failed_or_invalid?' do
      it 'returns true' do
        allow(faraday_response).to receive(:body) { body }
        expect(parser).to be_failed_or_invalid
      end
    end
  end

  context 'given a failure response' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_ar_code_database_error_response.xml')) }

    describe '#failed_or_invalid?' do
      it 'returns true' do
        allow(faraday_response).to receive(:body) { body }
        expect(parser).to be_failed_or_invalid
      end
    end
  end

  context 'given a multiple match' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_multiple_match_response.xml')) }

    before do
      allow(faraday_response).to receive(:body) { body }
    end

    describe '#failed_or_invalid?' do
      it 'returns false' do
        expect(parser).to be_failed_or_invalid
      end
    end

    describe '#multiple_match?' do
      it 'returns true' do
        expect(parser).to be_multiple_match
      end
    end
  end

  context 'with multiple MHV IDs' do
    let(:icn_with_aaid) { '12345678901234567^NI^200M^USVHA' }
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_multiple_mhv_response.xml')) }
    let(:mvi_profile) do
      build(
        :mpi_profile_response,
        :multiple_mhvids,
        historical_icns: nil,
        icn_with_aaid: icn_with_aaid,
        full_mvi_ids: [
          '12345678901234567^NI^200M^USVHA^P',
          '12345678^PI^200CORP^USVBA^A',
          '12345678901^PI^200MH^USVHA^A',
          '12345678902^PI^200MH^USVHA^D',
          '1122334455^NI^200DOD^USDOD^A',
          '0001234567^PN^200PROV^USDVA^A',
          '123412345^PI^200BRLS^USVBA^A'
        ],
        search_token: 'WSDOC1611060614456041732180196',
        person_type_code: 'Patient'
      )
    end

    before do
      allow(faraday_response).to receive(:body) { body }
    end

    it 'returns an array of mhv ids' do
      expect(parser.parse).to have_deep_attributes(mvi_profile)
    end
  end

  context 'with a vet360 id' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_response.xml')) }
    let(:mvi_profile) do
      build(
        :mpi_profile_response,
        :address_austin,
        historical_icns: nil,
        sec_id: nil,
        birls_id: nil,
        birls_ids: [],
        search_token: 'WSDOC1609131753362231779394902'
      )
    end

    before do
      allow(faraday_response).to receive(:body) { body }
    end

    it 'correctly parses a Vet360 ID' do
      expect(parser.parse).to have_deep_attributes(mvi_profile)
    end
  end

  context 'with inactive MHV ID edge cases' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/find_candidate_inactive_mhv_ids.xml')) }

    before do
      Settings.sentry.dsn = 'asdf'
      allow(faraday_response).to receive(:body) { body }
    end

    after { Settings.sentry.dsn = nil }

    it 'logs warning about inactive IDs' do
      msg1 = 'Inactive MHV correlation IDs present'
      msg2 = 'Returning inactive MHV correlation ID as first identifier'
      expect(Raven).to receive(:extra_context).with(ids: %w[12345678901 12345678902]).twice
      expect(Raven).to receive(:capture_message).with(msg1, level: 'info')
      expect(Raven).to receive(:capture_message).with(msg2, level: 'warning')
      parser.parse
    end
  end
end
