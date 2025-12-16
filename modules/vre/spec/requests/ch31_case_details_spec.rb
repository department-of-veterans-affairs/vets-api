# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VRE::V0::Ch31CaseDetails', type: :request do
  include SchemaMatchers

  describe 'GET vre/v0/ch31_case_details' do
    context 'when case details available' do
      it 'returns 200 response' do
        VCR.use_cassette('vre/ch31_case_details/200') do
          get '/vre/v0/ch31_case_details', headers: { Host: 'localhost' }
          expect(response).to match_response_schema('vre/ch31_case_details')
          assert_response :success
        end
      end
    end
  end
end
