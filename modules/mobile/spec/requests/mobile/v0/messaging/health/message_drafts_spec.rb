# frozen_string_literal: true

require_relative '../../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::Messaging::Health::MessageDrafts', type: :request do
  include SchemaMatchers

  let!(:user) { sis_user(:mhv, mhv_account_type: 'Premium') }
  let(:reply_id)               { 674_874 }
  let(:created_draft_id)       { 674_942 }
  let(:created_draft_reply_id) { 674_944 }
  let(:draft) { attributes_for(:message, body: 'Body 1', subject: 'Subject 1') }
  let(:params) { draft.slice(:category, :subject, :body, :recipient_id) }
  let(:draft_signature_only) { attributes_for(:message, body: '\n\n\n\nSignature\nExample', subject: 'Subject 1') }

  before do
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when user does not have access' do
    let!(:user) { sis_user(:mhv, mhv_account_type: 'Free') }

    it 'returns forbidden' do
      post('/mobile/v0/messaging/health/message_drafts', headers: sis_headers, params:)

      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when not authorized' do
    it 'responds with 403 error' do
      VCR.use_cassette('mobile/messages/session_error') do
        post('/mobile/v0/messaging/health/message_drafts', headers: sis_headers, params:)
      end
      expect(response).not_to be_successful
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'when authorized' do
    before do
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    describe 'drafts' do
      let(:params) { { message_draft: draft.slice(:category, :subject, :body, :recipient_id) } }
      let(:params_signature_only) do
        { message_draft: draft_signature_only.slice(:category, :subject, :body, :recipient_id) }
      end

      it 'responds to POST #create' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
          post '/mobile/v0/messaging/health/message_drafts', params:, headers: sis_headers
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'does not remove proceeding whitespace for #create with signature only' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_signature_only') do
          post '/mobile/v0/messaging/health/message_drafts', params: params_signature_only, headers: sis_headers
        end

        expect(response).to be_successful
        expect(response.parsed_body.dig('data', 'attributes', 'body')).to eq("\n\n\n\nSignature\nExample")
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      describe 'PUT #update' do
        it 'responds to PUT #update' do
          VCR.use_cassette('sm_client/message_drafts/updates_a_draft') do
            params[:subject] = 'Updated Subject'
            params[:id] = created_draft_id

            put "/mobile/v0/messaging/health/message_drafts/#{created_draft_id}", params:, headers: sis_headers
          end

          expect(response).to be_successful
          expect(response).to have_http_status(:no_content)
        end

        context 'when message does not exist' do
          it 'responds to PUT #update' do
            VCR.use_cassette('sm_client/messages/gets_a_message_thread_id_error') do
              params[:subject] = 'Updated Subject'
              params[:id] = 999_999

              put '/mobile/v0/messaging/health/message_drafts/999999', params:, headers: sis_headers
            end

            expected_error = { 'errors' => [{ 'title' => 'Operation failed',
                                              'detail' => 'Message requested could not be found',
                                              'code' => 'SM904',
                                              'source' => 'Severity[Error]:message.not.found;',
                                              'status' => '404' }] }
            expect(response).to have_http_status(:not_found)
            expect(response.parsed_body).to eq(expected_error)
          end
        end
      end
    end

    describe 'reply drafts' do
      let(:params) { { message_draft: draft.slice(:body) } }

      it 'responds to POST #create' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
          post "/mobile/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params:, headers: sis_headers
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('message')
        expect(response).to have_http_status(:created)
      end

      it 'does not remove proceeding whitespace for #create with signature only' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply_signature_only') do
          post "/mobile/v0/messaging/health/message_drafts/#{reply_id}/replydraft", params:, headers: sis_headers
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
              params:, headers: sis_headers
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
