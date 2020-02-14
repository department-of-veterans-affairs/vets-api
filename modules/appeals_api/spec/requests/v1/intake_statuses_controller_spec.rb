# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::V1::DecisionReview::IntakeStatusesController, type: :request do
  describe '#index' do
    it 'GET intake status from Caseflow successfully' do
      VCR.use_cassette('appeals/intake_status') do
        get(
          '/services/appeals/v1/decision_review/intake_statuses/97bca3d5-3524-4e5d-81ea-92753892a59c'
        )
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).not_to be nil
      end
    end

    it 'GET renders a successful response when a 303 is returned' do
      VCR.use_cassette('appeals/intake_status_redirect') do
        get(
          '/services/appeals/v1/decision_review/intake_statuses/ca9a8ab7-dff2-499b-8251-60b9d0300bc9'
        )
        expect(response.status).to eq(303)
        json = JSON.parse(response.body)
        expect(json['meta']).not_to be nil
        expect(json['meta']['Location']).not_to be nil
      end
    end
  end
end
