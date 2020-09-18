# frozen_string_literal: true

require 'rails_helper'
require 'mvi/responses/add_parser'

describe MVI::Responses::AddParser do
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:parser) { described_class.new(faraday_response) }

  context 'given a valid response' do
    let(:body) { Ox.parse(File.read('spec/support/mvi/add_person_response.xml')) }

    before do
      allow(faraday_response).to receive(:body) { body }
    end

    describe '#failed_or_invalid?' do
      it 'returns false' do
        expect(parser).not_to be_failed_or_invalid
      end
    end

    describe '#parse' do
      let(:codes) { { birls_id: '111985523', participant_id: '32397028' } }

      it 'returns a MviProfile with the parsed attributes' do
        expect(parser.parse).to have_deep_attributes(codes)
      end
    end

    describe '#parse_ids' do
      context 'when given a list of attributes' do
        let(:attributes) do
          [
            { codeSystemName: 'MVI', code: '111985523^PI^200BRLS^USVBA', displayName: 'IEN' },
            { codeSystemName: 'MVI', code: '32397028^PI^200CORP^USVBA', displayName: 'IEN' },
            { codeSystemName: 'MVI', code: 'WRN206', displayName: 'test error' }
          ]
        end

        let(:parsed_ids) do
          {
            other: [
              { codeSystemName: 'MVI', code: 'WRN206', displayName: 'test error' }
            ],
            birls_id: '111985523',
            participant_id: '32397028'
          }
        end

        it 'parses the ids correctly' do
          expect(parser.send(:parse_ids, attributes)).to eq parsed_ids
        end
      end
    end
  end

  context 'given an invalid response' do
    let(:body) { Ox.parse(File.read('spec/support/mvi/add_person_invalid_response.xml')) }

    describe '#failed_or_invalid?' do
      it 'returns true' do
        allow(faraday_response).to receive(:body) { body }
        expect(parser).to be_failed_or_invalid
        expect(PersonalInformationLog.last.error_class).to eq 'MVI::Errors'
      end
    end
  end

  context 'given an internal error response' do
    let(:body) { Ox.parse(File.read('spec/support/mvi/add_person_internal_error_response.xml')) }

    describe '#failed_or_invalid?' do
      it 'returns true' do
        allow(faraday_response).to receive(:body) { body }
        expect(parser).to be_failed_or_invalid
      end
    end
  end
end
