# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'dismissed statuses' do
  include SchemaMatchers

  let(:user) { build(:user, :accountable) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }
  let(:headers_with_camel) { headers.merge(inflection_header) }
  let(:notification_subject) { Notification::FORM_10_10EZ }

  before do
    sign_in_as(user)
  end

  describe 'GET /v0/notifications/dismissed_statuses/:subject' do
    context 'when user has an associated Notification record' do
      let!(:notification) do
        create :notification, :dismissed_status, account_id: user.account.id, read_at: Time.current
      end

      it 'matches the dismissed_statuses schema', :aggregate_failures do
        get "/v0/notifications/dismissed_statuses/#{notification_subject}"

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('dismissed_status')
      end

      it 'matches the dismissed_statuses camel-inflected schema', :aggregate_failures do
        get "/v0/notifications/dismissed_statuses/#{notification_subject}", headers: inflection_header

        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('dismissed_status')
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

  describe 'POST /v0/notifications/dismissed_statuses' do
    let(:post_body) do
      {
        subject: notification_subject,
        status: Notification::PENDING_MT,
        status_effective_at: '2019-04-23T00:00:00.000-06:00'
      }.to_json
    end

    context 'when user does *not* have a Notification record for the passed subject' do
      it 'matches the dismissed status schema', :aggregate_failures do
        post '/v0/notifications/dismissed_statuses', params: post_body, headers: headers

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('dismissed_status')
      end

      it 'matches the dismissed status camel-inflected schema', :aggregate_failures do
        post '/v0/notifications/dismissed_statuses', params: post_body, headers: headers_with_camel

        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('dismissed_status')
      end
    end

    context 'when user already has a Notification record for the passed subject' do
      let!(:notification) do
        create :notification, :dismissed_status, account_id: user.account.id, read_at: Time.current
      end

      it 'returns a 422 unprocessable entity', :aggregate_failures do
        post '/v0/notifications/dismissed_statuses', params: post_body, headers: headers

        expect(response.status).to eq 422
        expect(response.body).to include 'Subject has already been taken'
      end
    end

    context 'when the passed subject is not defined in the Notification#subject enum' do
      let(:invalid_subject) { 'random_subject' }
      let(:invalid_post_body) do
        {
          subject: invalid_subject,
          status: Notification::PENDING_MT,
          status_effective_at: '2019-04-23T00:00:00.000-06:00'
        }.to_json
      end

      it 'returns a 422 unprocessable entity', :aggregate_failures do
        post '/v0/notifications/dismissed_statuses', params: invalid_post_body, headers: headers

        expect(response.status).to eq 422
        expect(response.body).to include "#{invalid_subject} is not a valid subject"
      end
    end

    context 'when the passed dismissed_status is not defined in the Notification#status enum' do
      let(:invalid_status) { 'random_status' }
      let(:invalid_post_body) do
        {
          subject: notification_subject,
          status: invalid_status,
          status_effective_at: '2019-04-23T00:00:00.000-06:00'
        }.to_json
      end

      it 'returns a 422 unprocessable entity', :aggregate_failures do
        post '/v0/notifications/dismissed_statuses', params: invalid_post_body, headers: headers

        expect(response.status).to eq 422
        expect(response.body).to include "#{invalid_status} is not a valid status"
      end
    end
  end

  describe 'PATCH /v0/notifications/dismissed_statuses/:subject' do
    let(:patch_body) do
      {
        status: Notification::CLOSED,
        status_effective_at: '2019-04-23T00:00:00.000-06:00'
      }.to_json
    end

    context 'user has an existing Notification record with the passed subject' do
      let!(:notification) do
        create :notification, :dismissed_status, account_id: user.account.id, read_at: Time.current
      end

      it 'matches the dismissed status schema', :aggregate_failures do
        patch "/v0/notifications/dismissed_statuses/#{notification_subject}", params: patch_body, headers: headers

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('dismissed_status')
      end

      it 'matches the dismissed status camel-inflected schema', :aggregate_failures do
        patch "/v0/notifications/dismissed_statuses/#{notification_subject}",
              params: patch_body,
              headers: headers_with_camel

        expect(response).to have_http_status(:ok)
        expect(response).to match_camelized_response_schema('dismissed_status')
      end

      it 'correctly updates their Notification record', :aggregate_failures do
        patch "/v0/notifications/dismissed_statuses/#{notification_subject}", params: patch_body, headers: headers

        notification.reload
        body = JSON.parse(patch_body)

        expect(notification.status).to eq body['status']
        expect(notification.status_effective_at).to eq body['status_effective_at'].to_datetime
      end
    end

    context 'user does not have a Notification record with the passed subject' do
      it 'returns a 404 record not found', :aggregate_failures do
        patch "/v0/notifications/dismissed_statuses/#{notification_subject}", params: patch_body, headers: headers

        expect(response.status).to eq 404
        expect(response.body).to include 'Record not found'
      end
    end
  end
end
