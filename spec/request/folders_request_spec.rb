# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Folders Integration', type: :request do
  let(:user_id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }

  describe '#index' do
    before(:each) do
      VCR.use_cassette("sm/folders/#{user_id}/index") do
        get '/v0/messaging/health/folders'
      end
    end

    it 'responds to GET #index' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('folders')
    end
  end

  describe '#show' do
    context 'with valid id' do
      before(:each) do
        VCR.use_cassette("sm/folders/#{user_id}/show") do
          get "/v0/messaging/health/folders/#{inbox_id}"
        end
      end

      it 'response to GET #show' do
        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('folder')
      end
    end
  end
end
