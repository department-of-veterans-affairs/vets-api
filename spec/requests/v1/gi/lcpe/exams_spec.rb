# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::GI::LCPE::Exams', type: :request do
  include SchemaMatchers

  describe 'GET v1/gi/lcpe/exams' do
    context 'Retrieves exam data for GI Bill Comparison Tool' do
      it 'returns 200 response' do
        VCR.use_cassette('gi/lcpe/get_exams_v1') do
          get v1_gi_lcpe_exams_url, params: nil
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('gi/lcpe/exams')
        end
      end
    end
  end
end
