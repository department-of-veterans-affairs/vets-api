# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/mobile_sm_client_helper'

RSpec.describe 'Mobile Message Drafts Integration', type: :request do
  include Mobile::MessagingClientHelper
  include SchemaMatchers

  let(:user_id) { '10616687' }
  let(:reply_id)               { 674_874 }
  let(:created_draft_id)       { 674_942 }
  let(:created_draft_reply_id) { 674_944 }
  let(:draft) { attributes_for(:message, body: 'Body 1', subject: 'Subject 1') }
  let(:params) { draft.slice(:category, :subject, :body, :recipient_id) }
  let(:va_patient) { true }
  let(:draft_signature_only) { attributes_for(:message, body: '\n\n\n\nSignature\nExample', subject: 'Subject 1') }

  before do
    allow_any_instance_of(MHVAccountTypeService).to receive(:mhv_account_type).and_return(mhv_account_type)
    allow(Mobile::V0::Messaging::Client).to receive(:new).and_return(authenticated_client)
    iam_sign_in(build(:iam_user, iam_mhv_id: '123'))
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    it 'is not authorized' do
      post('/mobile/v0/messaging/health/message_drafts', headers: iam_headers, params:)
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    it 'is not authorized' do
      post('/mobile/v0/messaging/health/message_drafts', headers: iam_headers, params:)
      expect(response).not_to be_successful
      expect(response.status).to eq(403)
    end
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    describe 'drafts' do
      let(:params) { { message_draft: draft.slice(:category, :subject, :body, :recipient_id) } }
      let(:params_signature_only) do
        { message_draft: draft_signature_only.slice(:category, :subject, :body, :recipient_id) }
      end

      it 'responds to POST #create' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
          post '/mobile/v0/messaging/health/message_drafts', params:, headers: iam_headers
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'does not remove proceeding whitespace for #create with signature only' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_signature_only') do
          post '/mobile/v0/messaging/health/message_drafts', params: params_signature_only, headers: iam_headers
        end

        expect(response).to be_successful
        expect(response.parsed_body.dig('data', 'attributes', 'body')).to eq("\n\n\n\nSignature\nExample")
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to PUT #update' do
        VCR.use_cassette('sm_client/message_drafts/updates_a_draft') do
          params[:subject] = 'Updated Subject'
          params[:id] = created_draft_id

          put "/mobile/v0/messaging/health/message_drafts/#{created_draft_id}", params:, headers: iam_headers
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'reply drafts' do
      let(:params) { { message_draft: draft.slice(:body) } }

      it 'responds to POST #create' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
          post "/mobile/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params:, headers: iam_headers
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'does not remove proceeding whitespace for #create with signature only' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply_signature_only') do
          post "/mobile/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params:, headers: iam_headers
        end

        expect(response).to be_successful
        expect(response.parsed_body.dig('data', 'attributes', 'body')).to eq("\n\n\n\nSignature\nExample")
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to PUT #update' do
        VCR.use_cassette('sm_client/message_drafts/updates_a_draft_reply') do
          params[:body] = 'Updated Body'
          params[:id] = created_draft_reply_id
          put "/mobile/v0/messaging/health/message_drafts/#{reply_id}/replydraft/#{created_draft_reply_id}",
              params:, headers: iam_headers
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
