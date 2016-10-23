# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'

RSpec.describe 'sm', type: :request do
  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
  end

  let(:draft) { attributes_for(:message_draft) }

  describe 'message drafts' do
    let(:params) { { message_draft: draft.slice(:category, :subject, :body, :recipient_id) } }

    it 'responds to POST #create', :vcr do
      post '/v0/messaging/health/message_drafts', params

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
      expect(response).to have_http_status(:created)
    end

    it 'responds to PUT #update', :vcr do
      params[:message_draft][:subject] = 'Updated Subject'
      put "/v0/messaging/health/message_drafts/653149", params

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'reply drafts' do
    let(:params) { { message_draft: draft.slice(:body) } }
    let(:reply_id) { 631_270 }

    it 'responds to POST #create', :vcr do
      post "/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
      expect(response).to have_http_status(:created)
    end

    it 'responds to PUT #update', :vcr do
      params[:message_draft][:body] = 'Updated Body'
      put "/v0/messaging/health/message_drafts/#{reply_id}/replydraft/653146", params

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end
end
