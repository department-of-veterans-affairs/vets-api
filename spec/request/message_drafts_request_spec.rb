# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Messages Integration', type: :request do
  include SM::ClientHelpers

  let(:draft) { attributes_for(:message_draft) }
  let(:user_id) { ENV['MHV_SM_USER_ID'] }

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    expect(SM::Client).to receive(:new).once.and_return(authenticated_client)
  end

  describe 'drafts' do
    let(:params) { { message_draft: draft.slice(:category, :subject, :body, :recipient_id) } }
    let(:draft_to_update) { 653_450 }

    it 'responds to POST #create' do
      VCR.use_cassette('sm_client/message_drafts/creates_and_updates_new_message_draft') do
        post '/v0/messaging/health/message_drafts', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
      expect(response).to have_http_status(:created)
    end

    it 'responds to PUT #update' do
      VCR.use_cassette('sm_client/message_drafts/creates_and_updates_new_message_draft') do
        params[:subject] = 'Updated Subject'

        put "/v0/messaging/health/message_drafts/#{draft[:id]}", params
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'reply drafts' do
    let(:params) { { message_draft: draft.slice(:body) } }
    let(:reply_id) { 631_270 }
    let(:replydraft_to_update) { 653_456 }

    it 'responds to POST #create' do
      VCR.use_cassette('sm_client/message_drafts/creates_and_updates_new_message_draft_reply') do
        post "/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
      expect(response).to have_http_status(:created)
    end

    it 'responds to PUT #update' do
      VCR.use_cassette('sm_client/message_drafts/creates_and_updates_new_message_draft_reply') do
        params[:body] = 'Updated Body'
        put "/v0/messaging/health/message_drafts/#{reply_id}/replydraft/#{draft[:id]}", params
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end
end
