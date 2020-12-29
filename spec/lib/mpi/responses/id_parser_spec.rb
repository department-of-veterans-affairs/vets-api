# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/id_parser'

describe MPI::Responses::IdParser do
  describe '#parse' do
    context 'vba_corp_id' do
      let(:vba_corp_ids) do
        [correlation_id('87654321^PI^200CORP^USVBA^H'),
         correlation_id('87654322^PI^200CORP^USVBA^L'),
         correlation_id('12345678^PI^200CORP^USVBA^A')]
      end

      it 'matches correctly on all valid ID statuses (i.e. P and A)' do
        expect(MPI::Responses::IdParser.new.parse(vba_corp_ids)[:vba_corp_id]).to eq '12345678'
      end
    end

    context 'idme_id' do
      let(:expected_idme_id) { 'someidmeid' }
      let(:ids_to_parse) do
        [correlation_id('87654321^PI^200CORP^USVBA^H'),
         correlation_id("#{expected_idme_id}^PN^200VIDM^USDVA^A"),
         correlation_id('12345678^PI^200CORP^USVBA^A')]
      end

      it 'correctly parses the idme_id from ids to parse' do
        expect(MPI::Responses::IdParser.new.parse(ids_to_parse)[:idme_id]).to eq expected_idme_id
      end
    end

    context 'BIRLS' do
      let(:birls_ids) do
        [correlation_id('987654321^PI^200BRLS^USVBA^A'),
         correlation_id('123456789^PI^200BRLS^USVBA^A')]
      end

      it 'finds all BIRLS IDs' do
        expect(MPI::Responses::IdParser.new.parse(birls_ids)[:birls_ids]).to eq %w[987654321 123456789]
        expect(MPI::Responses::IdParser.new.parse(birls_ids)[:birls_id]).to eq '987654321'
      end
    end

    context 'icn_with_aaid' do
      let(:non_icn_id) { 'TKIP123456^PI^200IP^USVHA^A' }

      context 'with all valid ICN components' do
        it 'returns an ICN with an Assigning Authority ID & trims off the ID status', :aggregate_failures do
          expect_valid_icn_with_aaid_from_parsed_xml(
            xml_file: 'find_candidate_response',
            expected_icn_with_aaid: '1000123456V123456^NI^200M^USVHA'
          )

          expect_valid_icn_with_aaid_from_parsed_xml(
            xml_file: 'find_candidate_multiple_mhv_response',
            expected_icn_with_aaid: '12345678901234567^NI^200M^USVHA'
          )

          expect_valid_icn_with_aaid_from_parsed_xml(
            xml_file: 'find_candidate_valid_response',
            expected_icn_with_aaid: '1008714701V416111^NI^200M^USVHA'
          )
        end

        it 'matches correctly on the MPI::Responses::ProfileParser::ICN_REGEX' do
          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USVHA^P',
            '12345678901234567^NI^200M^USVHA'
          )
        end
      end

      context 'with non-P ID status' do
        it 'does not return a match', :aggregate_failures do
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200M^USVHA^A')
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200M^USVHA^D')
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200M^USVHA^L')
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200M^USVHA^H')
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200M^USVHA^PCE')
        end
      end

      context 'with a non-USVHA issuer' do
        it 'does not return a match', :aggregate_failures do
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200M^USVBA^P')
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200M^USDVA^P')
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200M^USDOD^P')
        end
      end

      context 'with a non-200M source' do
        it 'does not return a match', :aggregate_failures do
          expect_invalid_icn_to_return_nil('12345678901234567^NI^516^USVHA^P')
          expect_invalid_icn_to_return_nil('12345678901234567^NI^553^USVHA^P')
          expect_invalid_icn_to_return_nil('12345678901234567^NI^200HD^USVHA^P')
        end
      end

      context 'with a non-NI type' do
        it 'does not return a match', :aggregate_failures do
          expect_invalid_icn_to_return_nil('12345678901234567^AA^200M^USVHA^P')
          expect_invalid_icn_to_return_nil('12345678901234567^PI^200M^USVHA^P')
        end
      end
    end
  end

  describe '#parse_string' do
    context 'when input ids is nil' do
      it 'returns nil'
    end

    context 'input ids is a string of parsable ids separated by |' do
      let(:ids) { "#{expected_vba_corp_id}^PI^200CORP^USVBA^A|#{expected_idme_id}^PN^200VIDM^USDVA^A" }
      let(:expected_idme_id) { '12331231' }
      let(:expected_vba_corp_id) { '87654321' }
      let(:expected_parsed_result) do
        {
          icn: nil,
          sec_id: nil,
          mhv_ids: nil,
          active_mhv_ids: nil,
          edipi: nil,
          vba_corp_id: expected_vba_corp_id,
          idme_id: expected_idme_id,
          vha_facility_ids: nil,
          cerner_facility_ids: nil,
          cerner_id: nil,
          birls_ids: [],
          vet360_id: nil,
          icn_with_aaid: nil,
          birls_id: nil
        }
      end

      it 'creates a hash with correctly parsed ids' do
        expect(MPI::Responses::IdParser.new.parse_string(ids)).to eq expected_parsed_result
      end
    end
  end
end

def ids_in(body)
  original_body = body.locate(MPI::Responses::ProfileParser::BODY_XPATH)&.first
  subject = original_body.locate(MPI::Responses::ProfileParser::SUBJECT_XPATH)&.first
  patient = subject.locate(MPI::Responses::ProfileParser::PATIENT_XPATH)&.first

  patient.locate('id')
end

def correlation_id(extension)
  OpenStruct.new(attributes: { extension: extension, root: MPI::Responses::IdParser::VA_ROOT_OID })
end

def expect_valid_icn_with_aaid_from_parsed_xml(xml_file:, expected_icn_with_aaid:)
  body = Ox.parse(File.read("spec/support/mpi/#{xml_file}.xml"))
  correlation_ids = MPI::Responses::IdParser.new.parse(ids_in(body))

  expect(correlation_ids[:icn_with_aaid]).to eq expected_icn_with_aaid
end

def expect_valid_icn_with_aaid_to_be_returned(icn_with_aaid_with_id_status, valid_icn_with_aaid)
  ids = [correlation_id(non_icn_id), correlation_id(icn_with_aaid_with_id_status)]
  correlation_ids = MPI::Responses::IdParser.new.parse(ids)

  expect(correlation_ids[:icn_with_aaid]).to eq valid_icn_with_aaid
end

def expect_invalid_icn_to_return_nil(invalid_icn)
  ids = [correlation_id(non_icn_id), correlation_id(invalid_icn)]
  correlation_ids = MPI::Responses::IdParser.new.parse(ids)

  expect(correlation_ids[:icn_with_aaid]).to be_nil
end
