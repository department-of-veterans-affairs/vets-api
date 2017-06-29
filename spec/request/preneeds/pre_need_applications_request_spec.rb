# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Preneeds Application Integration', type: :request do
  include SchemaMatchers

  context 'with valid input' do
    let(:params) do
      { pre_need_request: build(:application_input).message }
    end

    it 'responds to POST #create' do
      VCR.use_cassette('preneeds/pre_need_applications/creates_a_pre_need_application') do
        post '/v0/preneeds/pre_need_applications', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('preneeds/receive_applications')
    end
  end
end
