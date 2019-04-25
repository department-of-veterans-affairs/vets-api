# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'dismissed statuses', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :accountable) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:notification_subject) { 'form_10_10ez' }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/notifications/dismissed_statuses/:subject' do
    context 'when user has an associated Notification record' do
      let!(:notification) do
        create :notification, :dismissed_status, account_id: user.account.id, read_at: Time.current
      end

      it 'should match the dismissed_statuses schema', :aggregate_failures do
        get "/v0/notifications/dismissed_statuses/#{notification_subject}"

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('dismissed_status')
      end
    end

    context 'when user has no associated Notification record' do
      it 'returns a 404 record not found', :aggregate_failures do
        get "/v0/notifications/dismissed_statuses/#{notification_subject}"

        expect(response.status).to eq 404
        expect(response.body).to include 'Record not found'
      end
    end
  end
end
