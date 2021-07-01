# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::V1::DecisionReviews::LegacyAppealsController, type: :request do
  describe '#index' do
    context 'when only ssn provided' do
      it 'GETs legacy appeals from Caseflow successfully' do
        # temporary cassette until caseflow endpoint complete and merged
        VCR.use_cassette('caseflow/legacy_appeals') do
          get_legacy_appeals(ssn: '120495723', file_number: nil)
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['data']).not_to be nil
        end
      end
    end

    context 'when only file_number provided' do
      it 'GETs legacy appeals from Caseflow successfully' do
        # temporary cassette until caseflow endpoint complete and merged
        VCR.use_cassette('caseflow/legacy_appeals') do
          get_legacy_appeals(ssn: nil, file_number: '987654')
          expect(response).to have_http_status(:ok)
          json = JSON.parse(response.body)
          expect(json['data']).not_to be nil
        end
      end
    end

    context 'when X-VA-SSN and X-VA-File-Number are missing' do
      it 'returns a 422' do
        # temporary cassette until caseflow endpoint complete and merged
        VCR.use_cassette('caseflow/legacy_appeals') do
          get_legacy_appeals(ssn: nil, file_number: nil)
          expect(response).to have_http_status(:unprocessable_entity)
          json = JSON.parse(response.body)
          expect(json['errors']).to be_an Array
        end
      end
    end
  end

  private

  def get_legacy_appeals(ssn: nil, file_number: nil)
    headers = {}

    if file_number.present?
      headers['X-VA-File-Number'] = file_number
    elsif ssn.present?
      headers['X-VA-SSN'] = ssn
    end

    get('/services/appeals/v1/decision_reviews/legacy_appeals/', headers: headers)
  end
end
