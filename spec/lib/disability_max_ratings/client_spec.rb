# frozen_string_literal: true

require 'rails_helper'
require 'disability_max_ratings/client'

RSpec.describe DisabilityMaxRatings::Client do
  let(:client) { DisabilityMaxRatings::Client.new }
  let(:max_ratings_params) { { diagnostic_codes: [1234] } }

  describe 'making max rating requests' do
    subject { client.post_for_max_ratings(max_ratings_params[:diagnostic_codes]) }

    context 'valid requests' do
      describe 'when requesting max ratings' do
        let(:generic_response) do
          double(
            'disability max ratings response', status: 200,
                                               body: {
                                                 ratings: [
                                                   diagnostic_code: 1234, max_rating: 100
                                                 ]
                                               }.as_json
          )
        end

        before do
          allow(client).to receive(:perform).and_return(generic_response)
        end

        it 'returns the API response' do
          expect(subject).to eq generic_response
        end
      end
    end

    context 'unsuccessful requests' do
      let(:error_state) do
        double(
          'disability max ratings response', status: 404,
                                             body: { message: 'Something went wrong.' }.as_json
        )
      end

      before do
        allow(client).to receive(:perform).and_return(error_state)
      end

      it 'handles an error' do
        expect(subject).to eq error_state
      end
    end
  end
end
