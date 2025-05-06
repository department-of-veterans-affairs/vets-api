# frozen_string_literal: true

require 'rails_helper'
require 'mpi/responses/add_parser'

describe MPI::Responses::AddParser do
  let(:faraday_response) { instance_double(Faraday::Env) }
  let(:parser) { described_class.new(faraday_response) }
  let(:mpi_codes) { { other: [{ codeSystemName: 'MVI', code: 'INTERR', displayName: 'Internal System Error' }] } }
  let(:error_details) do
    { other: mpi_codes[:other],
      error_details: { ack_detail_code:,
                       id_extension: '200VGOV-1373004c-e23e-4d94-90c5-5b101f6be54a',
                       error_texts: ['Internal System Error'] } }
  end
  let(:headers) { { 'x-global-transaction-id' => transaction_id } }
  let(:transaction_id) { 'some-transaction-id' }

  before do
    allow(faraday_response).to receive(:body) { body }
    allow(faraday_response).to receive(:response_headers) { headers }
  end

  context 'given a valid response' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_response.xml')) }

    describe '#failed_or_invalid?' do
      it 'returns false' do
        expect(parser).not_to be_failed_or_invalid
      end
    end

    describe '#parse' do
      let(:codes) { { birls_id: '111985523', participant_id: '32397028', transaction_id: } }

      it 'returns a MviProfile with the parsed attributes' do
        expect(parser.parse).to have_deep_attributes(codes)
      end
    end

    describe '#parse_ids' do
      context 'when given a list of attributes' do
        let(:birls_id) { '111985523' }
        let(:participant_id) { '32397028' }
        let(:logingov_uuid) { 'aa478abc-e494-4af1-9f87-d002f8fe1cda' }
        let(:idme_uuid) { '54e78de6140d473f87960f211be49c08' }
        let(:edipi) { '2107307560' }
        let(:icn) { '1013677486V514195' }
        let(:error) { 'WRN206' }
        let(:attributes) do
          [
            { codeSystemName: 'MVI', code: "#{birls_id}^PI^200BRLS^USVBA", displayName: 'IEN' },
            { codeSystemName: 'MVI', code: "#{participant_id}^PI^200CORP^USVBA", displayName: 'IEN' },
            { codeSystemName: 'MVI', code: "#{logingov_uuid}^PN^200VLGN^USDVA^A", displayName: 'IEN' },
            { codeSystemName: 'MVI', code: "#{idme_uuid}^PN^200VIDM^USDVA^A", displayName: 'IEN' },
            { codeSystemName: 'MVI', code: "#{edipi}^NI^200DOD^USDOD^A", displayName: 'IEN' },
            { codeSystemName: 'MVI', code: icn, displayName: 'ICN' },
            { codeSystemName: 'MVI', code: error, displayName: 'test error' }
          ]
        end

        let(:parsed_ids) do
          {
            other: [
              { codeSystemName: 'MVI', code: error, displayName: 'test error' }
            ],
            birls_id:,
            participant_id:,
            logingov_uuid:,
            idme_uuid:,
            edipi:,
            icn:
          }
        end

        it 'parses the ids correctly' do
          expect(parser.send(:parse_ids, attributes)).to eq parsed_ids
        end
      end
    end
  end

  context 'given an invalid response' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_invalid_response.xml')) }

    describe '#failed_or_invalid?' do
      it 'returns true' do
        expect(parser).to be_failed_or_invalid
        expect(PersonalInformationLog.last.error_class).to eq 'MPI::Errors'
      end
    end

    describe '#error_details' do
      let(:ack_detail_code) { 'AE' }

      it 'parses the MPI response for additional attributes' do
        expect(parser.error_details(mpi_codes)).to eq(error_details)
      end
    end
  end

  context 'given an internal error response' do
    let(:body) { Ox.parse(File.read('spec/support/mpi/add_person_internal_error_response.xml')) }

    describe '#failed_or_invalid?' do
      it 'returns true' do
        expect(parser).to be_failed_or_invalid
      end
    end

    describe '#error_details' do
      let(:ack_detail_code) { 'AR' }

      it 'parses the MPI response for additional attributes' do
        expect(parser.error_details(mpi_codes)).to eq(error_details)
      end
    end
  end
end
