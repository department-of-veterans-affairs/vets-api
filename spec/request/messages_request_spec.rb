# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Messages Integration', type: :request do
  let(:id) { ENV['MHV_SM_USER_ID'] }
  let(:inbox_id) { 0 }
  let(:message_id) { 573_302 }

  describe '#index' do
    before(:each) do
      VCR.use_cassette("messages/#{id}/index") do
        get "/v0/folders/#{inbox_id}/messages", id: id
      end
    end

    it 'responds to GET #index' do
      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('messages')
    end
  end

  describe '#show' do
    context 'with valid id' do
      before(:each) do
        VCR.use_cassette("messages/#{id}/show") do
          get "/v0/messages/#{message_id}", id: id
        end
      end

      it 'response to GET #show' do
        expect(response).to be_success
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
      end
    end
  end
end
