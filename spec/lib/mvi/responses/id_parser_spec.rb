# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

describe MVI::Responses::IdParser do
  describe '#parse' do
    context 'vba_corp_id' do
      let(:vba_corp_ids) do
        [correlation_id('87654321^PI^200CORP^USVBA^H'),
         correlation_id('87654322^PI^200CORP^USVBA^L'),
         correlation_id('12345678^PI^200CORP^USVBA^A')]
      end

      it 'matches correctly on all valid ID statuses (i.e. P and A)' do
        expect(MVI::Responses::IdParser.new.parse(vba_corp_ids)[:vba_corp_id]).to eq '12345678'
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

        it 'matches correctly on the MVI::Responses::ProfileParser::ICN_REGEX' do
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
end

def ids_in(body)
  original_body = body.locate(MVI::Responses::ProfileParser::BODY_XPATH)&.first
  subject = original_body.locate(MVI::Responses::ProfileParser::SUBJECT_XPATH)&.first
  patient = subject.locate(MVI::Responses::ProfileParser::PATIENT_XPATH)&.first

  patient.locate('id')
end

def correlation_id(extension)
  OpenStruct.new(attributes: { extension: extension, root: MVI::Responses::IdParser::VA_ROOT_OID })
end

def expect_valid_icn_with_aaid_from_parsed_xml(xml_file:, expected_icn_with_aaid:)
  body = Ox.parse(File.read("spec/support/mvi/#{xml_file}.xml"))
  correlation_ids = MVI::Responses::IdParser.new.parse(ids_in(body))

  expect(correlation_ids[:icn_with_aaid]).to eq expected_icn_with_aaid
end

def expect_valid_icn_with_aaid_to_be_returned(icn_with_aaid_with_id_status, valid_icn_with_aaid)
  ids = [correlation_id(non_icn_id), correlation_id(icn_with_aaid_with_id_status)]
  correlation_ids = MVI::Responses::IdParser.new.parse(ids)

  expect(correlation_ids[:icn_with_aaid]).to eq valid_icn_with_aaid
end

def expect_invalid_icn_to_return_nil(invalid_icn)
  ids = [correlation_id(non_icn_id), correlation_id(invalid_icn)]
  correlation_ids = MVI::Responses::IdParser.new.parse(ids)

  expect(correlation_ids[:icn_with_aaid]).to be_nil
end
