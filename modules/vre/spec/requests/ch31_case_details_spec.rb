# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VRE::V0::Ch31CaseDetails', type: :request do
  include SchemaMatchers

  before { sign_in_as(user) }

  describe 'GET vre/v0/ch31_case_details' do
    let(:user) { create(:user, icn: '1012662125V786396') }

    context 'when case details available' do
      it 'returns 200 response' do
        VCR.use_cassette('vre/ch31_case_details/200') do
          get '/vre/v0/ch31_case_details'
          byebug
          expect(response).to match_response_schema('vre/ch31_case_details')
          assert_response :success
        end
      end
    end
  end
end
