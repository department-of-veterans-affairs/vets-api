# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::RatedDisabilitiesDiscrepanciesController, type: :controller do
  let(:user) { create(:user, :loa3, icn: '123498767V234859') }

  before do
    sign_in_as(user)

    token = 'blahblech'

    allow(Rails.logger).to receive(:info)

    allow_any_instance_of(VeteranVerification::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#show' do
    context 'when successful' do
      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_tinnitus_max_rated') do
            get(:show)
          end
        end

        expect(response).to have_http_status(:ok)
      end

      it 'detects discrepancies in the number of disability ratings returned' do
        VCR.use_cassette('lighthouse/veteran_verification/show/200_response') do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_tinnitus_max_rated') do
            get(:show)
          end
        end

        expect(response).to have_http_status(:ok)

        # Lighthouse should return 3 items, but filter out the inactive one, so when comparing
        # with EVSS (which should return 1 rating), there should be a discrepancy of 1 ratings
        expect(Rails.logger).to have_received(:info).with(
          'Discrepancy between Lighthouse and EVSS disability ratings',
          {
            message_type: 'lh.rated_disabilities.length_discrepancy',
            evss_length: 1,
            evss_rating_ids: ['1'],
            lighthouse_length: 2,
            lighthouse_rating_ids: %w[1 2],
            revision: 5
          }
        )
      end

      it 'filters out ratings with unwanted decisions' do
        VCR.use_cassette('lighthouse/veteran_verification/disability_rating/200_deferred_response') do
          VCR.use_cassette('evss/disability_compensation_form/rated_disabilities_tinnitus_max_rated') do
            get(:show)
          end
        end

        expect(response).to have_http_status(:ok)

        # Lighthouse should return 4 total items, but filter out the deferred one,
        # so when comparing with EVSS (which should return 1 rating), there should be
        # a discrepancy of 2 ratings
        expect(Rails.logger).to have_received(:info).with(
          'Discrepancy between Lighthouse and EVSS disability ratings',
          {
            message_type: 'lh.rated_disabilities.length_discrepancy',
            evss_length: 1,
            evss_rating_ids: ['1'],
            lighthouse_length: 3,
            lighthouse_rating_ids: %w[1 3 5],
            revision: 5
          }
        )
      end
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
