# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::V1::DecisionReview::ContestableIssuesController, type: :request do
  describe '#index' do
    it 'GETs contestable_issues from Caseflow successfully' do
      VCR.use_cassette('appeals/contestable_issues') do
        get(
          '/services/appeals/v1/decision_review/contestable_issues',
          headers: {
            'X-VA-SSN' => '872958715',
            'X-VA-Receipt-Date' => '2019-12-01'
          }
        )
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']).not_to be nil
      end
    end
  end
end
