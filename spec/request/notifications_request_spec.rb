# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'notifications', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :accountable) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:notification_subject) { Notification::DASHBOARD_HEALTH_CARE_APPLICATION_NOTIFICATION }

  before do
    sign_in_as(user)
  end

  describe 'POST /v0/notifications' do
    let(:post_body) do
      {
        subject: notification_subject,
        read: false
      }.to_json
    end

    context 'when user does *not* have a Notification record for the passed subject' do
      it 'should match the notification schema', :aggregate_failures do
        post '/v0/notifications', params: post_body, headers: headers

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('notification')
      end

      it 'sets the passed values', :aggregate_failures do
        post '/v0/notifications', params: post_body, headers: headers

        notification = user.account.notifications.first

        expect(notification.subject).to eq notification_subject.to_s
        expect(notification.read_at).to be_nil
      end

      context 'when read: true' do
        let(:post_body) do
          {
            subject: notification_subject,
            read: true
          }.to_json
        end

        it 'should set read_at: Time.current', :aggregate_failures do
          post '/v0/notifications', params: post_body, headers: headers

          read_at = JSON.parse(response.body).dig('data', 'attributes', 'read_at')

          expect(read_at).to be_present
          expect(read_at.class).to eq String
        end
      end
    end

    context 'when user already has a Notification record for the passed subject' do
      let!(:notification) do
        create :notification, subject: notification_subject, account_id: user.account.id
      end

      it 'returns a 422 unprocessable entity', :aggregate_failures do
        post '/v0/notifications', params: post_body, headers: headers

        expect(response.status).to eq 422
        expect(response.body).to include 'Subject has already been taken'
      end
    end

    context 'when the passed subject is not defined in the Notification#subject enum' do
      let(:invalid_subject) { 'random_subject' }
      let(:invalid_post_body) do
        {
          subject: invalid_subject,
          read: false
        }.to_json
      end

      it 'should return a 422 unprocessable entity', :aggregate_failures do
        post '/v0/notifications', params: invalid_post_body, headers: headers

        expect(response.status).to eq 422
        expect(response.body).to include "#{invalid_subject} is not a valid subject"
      end
    end
  end
end
