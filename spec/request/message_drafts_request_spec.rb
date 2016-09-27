# frozen_string_literal: true
require 'rails_helper'
require 'sm/client'
require 'support/sm_client_helpers'

RSpec.describe 'Messages Integration', type: :request do
  include SM::ClientHelpers

  let(:draft) { attributes_for(:message_draft) }
  let(:params) { { message_draft: draft.slice(:category, :subject, :body, :recipient_id) } }
  let(:user_id) { ENV['MHV_SM_USER_ID'] }

  before(:each) do
    allow_any_instance_of(ApplicationController).to receive(:authenticate).and_return(true)
    expect(SM::Client).to receive(:new).once.and_return(authenticated_client)
  end

  context 'with valid attributes' do
    it 'responds to POST #create' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/create") do
        post '/v0/messaging/health/message_drafts', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('message')
    end

    it 'responds to PUT #update' do
      VCR.use_cassette("sm/message_drafts/#{user_id}/update") do
        params[:subject] = 'Updated Subject'

        put "/v0/messaging/health/message_drafts/#{draft[:id]}", params
      end

      expect(response).to be_success
    end
  end
end
