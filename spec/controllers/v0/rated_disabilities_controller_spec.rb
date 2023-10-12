# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::RatedDisabilitiesController, type: :controller do
  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }

  before do
    sign_in_as(user)

    token = 'blahblech'

    allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#show' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
          get(:show)
        end

        expect(response).to have_http_status(:ok)
      end
    end

    it 'only return active ratings' do
      VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
        get(:show)
      end

      expect(response).to have_http_status(:ok)

      # VCR Cassette should have 3 items in the individual_ratings array, only 2 should
      # be "active"
      parsed_body = JSON.parse(response.body)
      expect(parsed_body.dig('data', 'attributes', 'individual_ratings').length).to eq(2)
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/401_response') do
          get(:show)
        end

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when ICN not found' do
      it 'returns a status of 404' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/404_ICN_response') do
          get(:show)
        end

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when there is a gateway timeout' do
      it 'returns a status of 504' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/504_response') do
          get(:show)
        end

        expect(response).to have_http_status(:gateway_timeout)
      end
    end
  end
end
