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

      context 'with a valid ID status (anything other than ^H or ^PCE, i.e. ^P or ^A)' do
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

        it 'matches correctly on all valid ID statuses (i.e. P and A)', :aggregate_failures do
          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USVHA^P',
            '12345678901234567^NI^200M^USVHA'
          )

          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USVHA^A',
            '12345678901234567^NI^200M^USVHA'
          )
        end

        it 'matches correctly on all issuers (i.e. USVHA, USVBA, USDVA, USDOD)', :aggregate_failures do
          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USVHA^P',
            '12345678901234567^NI^200M^USVHA'
          )

          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USVBA^P',
            '12345678901234567^NI^200M^USVBA'
          )

          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USDVA^P',
            '12345678901234567^NI^200M^USDVA'
          )

          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USDOD^P',
            '12345678901234567^NI^200M^USDOD'
          )
        end

        it 'matches correctly on all sources (i.e. 200M, 516, 553, 200HD)', :aggregate_failures do
          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USVHA^P',
            '12345678901234567^NI^200M^USVHA'
          )

          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^516^USVHA^P',
            '12345678901234567^NI^516^USVHA'
          )

          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^553^USVHA^P',
            '12345678901234567^NI^553^USVHA'
          )

          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200HD^USVHA^P',
            '12345678901234567^NI^200HD^USVHA'
          )
        end

        it 'only matches when the type is NI', :aggregate_failures do
          invalid_icn_with_aaid = '12345678901234567^AA^200M^USVHA^P'
          ids = [correlation_id(non_icn_id), correlation_id(invalid_icn_with_aaid)]

          correlation_ids = MVI::Responses::IdParser.new.parse(ids)

          expect(correlation_ids[:icn_with_aaid]).to eq nil
        end
      end

      context 'with an invalid ID status (meaning ^H or ^PCE)' do
        it 'sets the icn_with_aaid to nil' do
          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USVHA^H',
            nil
          )

          expect_valid_icn_with_aaid_to_be_returned(
            '12345678901234567^NI^200M^USVHA^PCE',
            nil
          )
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
  OpenStruct.new(attributes: { extension: extension, root: MVI::Responses::IdParser::CORRELATION_ROOT_ID })
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
