# frozen_string_literal: true

require 'rails_helper'
require 'ostruct'

describe MVI::Responses::IdParser do
  describe '#parse' do
    context 'icn_with_aaid' do
      let(:non_icn_id) { 'TKIP123456^PI^200IP^USVHA^A' }

      it 'finds, parses and returns an ICN with the Assigning Authority ID from a list of correlation ids', :aggregate_failures do
        expect_valid_icn_with_aaid_from_parsed_xml(
          xml_file: 'find_candidate_response',
          expected_icn_with_aaid: '1000123456V123456^NI^200M^USVHA^P'
        )

        expect_valid_icn_with_aaid_from_parsed_xml(
          xml_file: 'find_candidate_multiple_mhv_response',
          expected_icn_with_aaid: '12345678901234567^NI^200M^USVHA^P'
        )

        expect_valid_icn_with_aaid_from_parsed_xml(
          xml_file: 'find_candidate_valid_response',
          expected_icn_with_aaid: '1008714701V416111^NI^200M^USVHA^P'
        )
      end

      it 'matches correctly on the MVI::Responses::ProfileParser::ICN_REGEX' do
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USVHA^P')
      end

      it 'matches correctly on all ID statuses (i.e. P, A, H, PCE)', :aggregate_failures do
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USVHA^P')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USVHA^A')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USVHA^H')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USVHA^PCE')
      end

      it 'matches correctly on all issuers (i.e. USVHA, USVBA, USDVA, USDOD)', :aggregate_failures do
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USVHA^P')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USVBA^P')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USDVA^P')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USDOD^P')
      end

      it 'matches correctly on all sources (i.e. 200M, 516, 553, 200HD)', :aggregate_failures do
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200M^USVHA^P')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^516^USVHA^P')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^553^USVHA^P')
        expect_valid_icn_with_aaid_to_be_returned('12345678901234567^NI^200HD^USVHA^P')
      end

      it 'only matches when the type is NI', :aggregate_failures  do
        invalid_icn_with_aaid = '12345678901234567^AA^200M^USVHA^P'
        ids = [correlation_id(non_icn_id), correlation_id(invalid_icn_with_aaid)]

        correlation_ids = MVI::Responses::IdParser.new.parse(ids)

        expect(correlation_ids[:icn_with_aaid]).to eq nil
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
  OpenStruct.new(attributes: { extension: extension, root: MVI::Responses::IdParser::CORRELATION_ROOT_ID })
end

def expect_valid_icn_with_aaid_from_parsed_xml(xml_file:, expected_icn_with_aaid:)
  body = Ox.parse(File.read("spec/support/mvi/#{xml_file}.xml"))
  correlation_ids = MVI::Responses::IdParser.new.parse(ids_in(body))

  expect(correlation_ids[:icn_with_aaid]).to eq expected_icn_with_aaid
end

def expect_valid_icn_with_aaid_to_be_returned(valid_icn_with_aaid)
  ids = [correlation_id(non_icn_id), correlation_id(valid_icn_with_aaid)]
  correlation_ids = MVI::Responses::IdParser.new.parse(ids)

  expect(correlation_ids[:icn_with_aaid]).to eq valid_icn_with_aaid
end
