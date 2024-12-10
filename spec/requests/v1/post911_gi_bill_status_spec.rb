# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::Post911GIBillStatus', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, icn: '1012667145V762142') }

  before do
    # TO-DO: Remove once new VCR recorded for updated Post-911 GI Bill Status response
    Flipper.disable(:sob_updated_design)
    sign_in_as(user)
  end

  context 'with a 200 response' do
    it 'GET /v1/post911_gi_bill_status returns proper json' do
      VCR.use_cassette('lighthouse/benefits_education/gi_bill_status/200_response') do
        get v1_post911_gi_bill_status_url, params: nil
        expect(response).to match_response_schema('post911_gi_bill_status')
        assert_response :success
      end
    end
  end

  context 'with deprecated GibsNotFoundUser class' do
    it 'loads the class for coverage', skip: 'No expectation in this example' do
      GibsNotFoundUser
    end
  end
end
