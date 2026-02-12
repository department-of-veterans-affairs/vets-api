# frozen_string_literal: true

require 'rails_helper'
require 'support/sm_client_helpers'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V1::Messaging::MessageDrafts', type: :request do
  include SM::ClientHelpers
  include SchemaMatchers

  let(:reply_id)               { 674_874 }
  let(:created_draft_id)       { 674_942 }
  let(:created_draft_reply_id) { 674_944 }
  let(:draft) { attributes_for(:message, body: 'Body 1', subject: 'Subject 1') }
  let(:params) { draft.slice(:category, :subject, :body, :recipient_id) }
  let(:current_user) { build(:user, :mhv) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  before do
    sign_in_as(current_user)
    Timecop.freeze(Time.zone.parse('2017-05-01T19:25:00Z'))
  end

  after do
    Timecop.return
  end

  context 'when NOT authorized' do
    before do
      VCR.insert_cassette('sm_client/session_error')
      post '/my_health/v1/messaging/message_drafts', params:
    end

    after do
      VCR.eject_cassette
    end

    include_examples 'for user account level', message: 'You do not have access to messaging'
  end

  context 'when authorized' do
    before do
      # Stub get_triage_teams_station_numbers to avoid additional API call for OH migration phase
      allow_any_instance_of(SM::Client).to receive(:get_triage_teams_station_numbers).and_return([])
      VCR.insert_cassette('sm_client/session')
    end

    after do
      VCR.eject_cassette
    end

    describe 'drafts' do
      let(:params) { { message_draft: draft.slice(:category, :subject, :body, :recipient_id) } }

      it 'responds to POST #create' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
          post '/my_health/v1/messaging/message_drafts', params:
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/messaging/v1/message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to POST #create when camel-inflected' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft') do
          post '/my_health/v1/messaging/message_drafts', params:, headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('my_health/messaging/v1/message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to PUT #update' do
        VCR.use_cassette('sm_client/message_drafts/updates_a_draft') do
          params[:subject] = 'Updated Subject'
          params[:id] = created_draft_id

          put "/my_health/v1/messaging/message_drafts/#{created_draft_id}", params:
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end

    describe 'reply drafts' do
      let(:params) { { message_draft: draft.slice(:body) } }

      it 'responds to POST #create' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
          post "/my_health/v1/messaging/message_drafts/#{reply_id}/replydraft", params:
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_response_schema('my_health/messaging/v1/message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to POST #create when camel-inflected' do
        VCR.use_cassette('sm_client/message_drafts/creates_a_draft_reply') do
          post "/my_health/v1/messaging/message_drafts/#{reply_id}/replydraft", params:,
                                                                                headers: inflection_header
        end

        expect(response).to be_successful
        expect(response.body).to be_a(String)
        expect(response).to match_camelized_response_schema('my_health/messaging/v1/message')
        expect(response).to have_http_status(:created)
      end

      it 'responds to PUT #update' do
        VCR.use_cassette('sm_client/message_drafts/updates_a_draft_reply') do
          params[:body] = 'Updated Body'
          params[:id] = created_draft_reply_id
          put "/my_health/v1/messaging/message_drafts/#{reply_id}/replydraft/#{created_draft_reply_id}", params:
        end

        expect(response).to be_successful
        expect(response).to have_http_status(:no_content)
      end
    end
  end
end
