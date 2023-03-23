# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'Messages Integration' do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:reply_id)               { 674_874 }
  let(:created_draft_id)       { 674_942 }
  let(:created_draft_reply_id) { 674_944 }
  let(:draft) { attributes_for(:message, body: 'Body 1', subject: 'Subject 1') }
  let(:params) { draft.slice(:category, :subject, :body, :recipient_id) }
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv, va_patient:, mhv_account_type:) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    allow(SM::Client).to receive(:new).and_return(authenticated_client)
    sign_in_as(current_user)
  end

  context 'Basic User' do
    let(:mhv_account_type) { 'Basic' }

    before { post '/v0/messaging/health/message_drafts', params: }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Advanced User' do
    let(:mhv_account_type) { 'Advanced' }

    before { post '/v0/messaging/health/message_drafts', params: }

    include_examples 'for user account level', message: 'You do not have access to messaging'
    include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
  end

  context 'Premium User' do
    let(:mhv_account_type) { 'Premium' }

    context 'not a va patient' do
      before { post '/v0/messaging/health/message_drafts', params: }

      let(:va_patient) { false }
      let(:current_user) do
        build(:user, :mhv, :no_vha_facilities, va_patient:, mhv_account_type:)
      end

      include_examples 'for non va patient user', authorized: false, message: 'You do not have access to messaging'
    end

    describe 'drafts' do
      let(:params) { { message_draft: draft.slice(:category, :subject, :body, :recipient_id) } }

      it 'responds to POST #create' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
          post '/v0/messaging/health/message_drafts', params:
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to POST #create when camel-inflected' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
          post '/v0/messaging/health/message_drafts', params:, headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to PUT #update' do
        VCR.use_cassette('sm_client/message_drafts/updates_a_draft') do
          params[:subject] = 'Updated Subject'
          params[:id] = created_draft_id

          put "/v0/messaging/health/message_drafts/#{created_draft_id}", params:
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'reply drafts' do
      let(:params) { { message_draft: draft.slice(:body) } }

      it 'responds to POST #create' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
          post "/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params:
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to POST #create when camel-inflected' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
          post "/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params:, headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to PUT #update' do
        VCR.use_cassette('sm_client/message_drafts/updates_a_draft_reply') do
          params[:body] = 'Updated Body'
          params[:id] = created_draft_reply_id
          put "/v0/messaging/health/message_drafts/#{reply_id}/replydraft/#{created_draft_reply_id}", params:
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
