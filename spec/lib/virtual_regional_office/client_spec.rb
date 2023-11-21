# frozen_string_literal: true

require 'rails_helper'
require 'virtual_regional_office/client'

RSpec.describe VirtualRegionalOffice::Client do
  let(:client) { VirtualRegionalOffice::Client.new }
  let(:classification_contention_params) do
    {
      diagnostic_code: 1234,
      claim_id: 4567,
      form526_submission_id: 789
    }
  end
  let(:max_ratings_params) do
    {
      diagnostic_codes: [1234]
    }
  end

  describe 'making classification contention requests' do
    subject { client.classify_single_contention(classification_contention_params) }

    context 'valid requests' do
      describe 'when requesting classification' do
        let(:generic_response) do
          double(
            'virtual regional office response', status: 200,
                                                body: {
                                                  classification_code: '99999', classification_name: 'namey'
                                                }.as_json
          )
        end

        before do
          allow(client).to receive(:perform).and_return generic_response
        end

        it 'returns the api response' do
          expect(subject).to eq generic_response
        end
      end
    end

    context 'unsuccessful requests' do
      let(:error_state) do
        double('virtual regional office response', status: 404, body: { message: 'No evidence found.' }.as_json)
      end

      before do
        allow(client).to receive(:perform).and_return error_state
      end

      it 'handles an error' do
        expect(subject).to eq error_state
      end
    end
  end

  describe 'making max rating requests' do
    subject { client.get_max_rating_for_diagnostic_codes(max_ratings_params) }

    context 'valid requests' do
      describe 'when requesting max ratings' do
        let(:generic_response) do
          double(
            'virtual regional office response', status: 200,
                                                body: {
                                                  ratings: [
                                                    diagnostic_code: 99_999, max_rating: 100
                                                  ]
                                                }.as_json
          )
        end

        before do
          allow(client).to receive(:perform).and_return generic_response
        end

        it 'returns the api response' do
          expect(subject).to eq generic_response
        end
      end
    end

    context 'unsuccessful requests' do
      let(:error_state) do
        double('virtual regional office response', status: 404, body: { message: 'Something went wrong.' }.as_json)
      end

      before do
        allow(client).to receive(:perform).and_return error_state
      end

      it 'handles an error' do
        expect(subject).to eq error_state
      end
    end
  end
end
