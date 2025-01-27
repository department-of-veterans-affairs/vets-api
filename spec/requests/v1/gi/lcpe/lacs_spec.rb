# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::GI::LCPE::Lacs', type: :request do
  include SchemaMatchers

  describe 'GET v1/gi/lcpe/lacs' do
    context 'Retrieves licenses and certifications data for GI Bill Comparison Tool' do
      it 'returns 200 response' do
        VCR.use_cassette('gi/lcpe/get_licenses_and_certs_v1') do
          get v1_gi_lcpe_lacs_url, params: nil
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('gi/lcpe/lacs')
        end
      end
    end
  end

  describe 'GET v1/gi/lcpe/lacs/:id' do
    context 'Retrieves license and certification details for GI Bill Comparison Tool' do
      it 'returns 200 response' do
        VCR.use_cassette('gi/lcpe/get_license_and_cert_details_v1') do
          get "#{v1_gi_lcpe_lacs_url}/1@f9822"
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('gi/lcpe/lac')
        end
      end
    end
  end
end
