# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Preneeds Application Form Integration', type: :request do
  include SchemaMatchers
  before(:each) { Redis.current.flushall }

  context 'with valid input' do
    let(:params) do
      { pre_need_request: build(:application_form).message }
    end

    it 'responds to POST #create' do
      VCR.use_cassette('preneeds/application_forms/creates_a_pre_need_application_form') do
        post '/v0/preneeds/application_forms', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('preneeds/receive_applications')
    end
  end
end
