# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::DisabilityCompensationForm::RatingInfo' do
  include SchemaMatchers

  let(:user) { build(:disabilities_compensation_user) }

  before do
    sign_in_as(user)
    Flipper.disable('profile_lighthouse_rating_info') # rubocop:disable Project/ForbidFlipperToggleInSpecs
  end

  describe 'GET /v0/disability_compensation_form/rating_info' do
    context 'with a valid 200 evss response' do
      it 'matches the rating info schema' do
        VCR.use_cassette('evss/disability_compensation_form/rating_info') do
          get '/v0/disability_compensation_form/rating_info'
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'with a 403 unauthorized response' do
      let(:user) { build(:unauthorized_evss_user, :loa3) }

      it 'returns a forbidden response' do
        VCR.use_cassette('evss/disability_compensation_form/rating_info_403') do
          get '/v0/disability_compensation_form/rating_info'
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_response_schema('evss_errors', strict: false)
        end
      end

      it 'returns a forbidden response when camel-inflected' do
        VCR.use_cassette('evss/disability_compensation_form/rating_info_403') do
          get '/v0/disability_compensation_form/rating_info', headers: { 'X-Key-Inflection' => 'camel' }
          expect(response).to have_http_status(:forbidden)
          expect(response).to match_camelized_response_schema('evss_errors', strict: false)
        end
      end
    end
  end
end
