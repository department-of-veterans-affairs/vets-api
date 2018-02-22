# frozen_string_literal: true

require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Messages Integration', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:mhv_account) { double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, accessible?: true) }
  let(:current_user) { build(:user, :mhv) }
  let(:reply_id)               { 674_874 }
  let(:created_draft_id)       { 674_942 }
  let(:created_draft_reply_id) { 674_944 }
  let(:draft) { attributes_for(:message, body: 'Body 1', subject: 'Subject 1') }
  let(:params) { draft.slice(:category, :subject, :body, :recipient_id) }

  before(:each) do
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    use_authenticated_current_user(current_user: current_user)
  end

  describe 'drafts' do
    let(:params) { { message_draft: draft.slice(:category, :subject, :body, :recipient_id) } }

    it 'responds to POST #create' do
      VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
        post '/v0/messaging/health/message_drafts', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
      expect(response).to have_http_status(:created)
    end

    it 'responds to PUT #update' do
      VCR.use_cassette('sm_client/message_drafts/updates_a_draft') do
        params[:subject] = 'Updated Subject'
        params[:id] = created_draft_id

        put "/v0/messaging/health/message_drafts/#{created_draft_id}", params
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'reply drafts' do
    let(:params) { { message_draft: draft.slice(:body) } }

    it 'responds to POST #create' do
      VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
        post "/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
      expect(response).to have_http_status(:created)
    end

    it 'responds to PUT #update' do
      VCR.use_cassette('sm_client/message_drafts/updates_a_draft_reply') do
        params[:body] = 'Updated Body'
        params[:id] = created_draft_reply_id
        put "/v0/messaging/health/message_drafts/#{reply_id}/replydraft/#{created_draft_reply_id}", params
      end

      expect(response).to be_success
      expect(response).to have_http_status(:no_content)
    end
  end
end
