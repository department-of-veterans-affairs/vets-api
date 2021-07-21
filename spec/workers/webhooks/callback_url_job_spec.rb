# frozen_string_literal: true

require 'rails_helper'
require_relative 'job_tracking'
Thread.current['under_test'] = true
require_dependency './lib/webhooks/utilities'
require_relative 'registrations'

RSpec.describe Webhooks::CallbackUrlJob, type: :job do

  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:consumer_id) do
    'f7d83733-a047-413b-9cce-e89269dcb5b1'
  end
  let(:consumer_name) do
    'tester'
  end
  let(:api_id) do
    '43581f6f-448c-4ed3-846a-68a004c9b78b'
  end
  let(:msg) do
    {'msg' => 'the message'}
  end
  let(:observers_json) {
    {
        "subscriptions" => [
            {
                "event" => Registrations::TEST_EVENT,
                "urls" => [
                    "https://i/am/listening",
                    "https://i/am/also/listening"
                ]
            }
        ]
    }
  }
  let(:urls) do
    observers_json['subscriptions'].first['urls']
  end

  before do
    @subscription = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers_json, api_id)
    @notifications = Webhooks::Utilities.record_notification(
        consumer_id: consumer_id,
        consumer_name: consumer_name,
        event: 'test_event',
        api_guid: api_id,
        msg: msg
    )
    Thread.current['job_ids'] = []
  end

  def mock_faraday(status, body, success)
    allow(Faraday).to receive(:post).and_return(faraday_response)
    allow(faraday_response).to receive(:status).and_return(status)
    allow(faraday_response).to receive(:body).and_return(body)
    allow(faraday_response).to receive(:success?).and_return(success)
  end

  it 'notifies the callback urls' do
    mock_faraday(200, '', true)
    urls.each { |url|
      @notification_by_url = @notifications.select do |n|
        n.callback_url.eql? url
      end.map(&:id)
      described_class.new.perform(url, @notification_by_url, Registrations::MAX_RETRIES)
    }
    @notifications.each do |notification_row|
      notification_row.reload
      expect(notification_row.final_attempt_id).to be_an(Integer)
      attempt = WebhookNotificationAttempt.find_by(id: notification_row.final_attempt_id)
      expect(attempt.success).to be true
      expect(attempt.response['status']).to be 200
    end

  end

  context 'failures' do

    it 'records failure attempts from a responsive callback url' do
      mock_faraday(400, '', false)
      urls.each { |url|
        @notification_by_url = @notifications.select do |n|
          n.callback_url.eql? url
        end.map(&:id)
        described_class.new.perform(url, @notification_by_url, Registrations::MAX_RETRIES)
      }
      @notifications.each do |notification_row|
        notification_row.reload
        expect(notification_row.final_attempt_id).to be nil
        wnaa = WebhookNotificationAttemptAssoc.where(webhook_notification_id: notification_row.id)
        expect(wnaa.count).to be 1
        wnaa.each do |w|
          attempt = WebhookNotificationAttempt.find_by(id: w.webhook_notification_attempt_id)
          expect(attempt.success).to be false
          expect(attempt.response['status']).to be 400
        end
      end
    end

    it 'the final attempt id is set if we fail max retries and we try max retries' do
      mock_faraday(400, '', false)
      urls.each { |url|
        @notification_by_url = @notifications.select do |n|
          n.callback_url.eql? url
        end.map(&:id)
        Registrations::MAX_RETRIES.times do
          described_class.new.perform(url, @notification_by_url, Registrations::MAX_RETRIES)
        end
      }
      @notifications.each do |notification_row|
        notification_row.reload
        expect(notification_row.final_attempt_id).to be_an(Integer)
        expect(notification_row.webhook_notification_attempts.count).to be Registrations::MAX_RETRIES
      end
    end

    it 'records failure attempts from an unresponsive callback url' do
      [Faraday::ClientError.new('busted'), StandardError.new('busted')].each do |error|
        # standard error forces exercise of last exception block
        allow(Faraday).to receive(:post).and_raise(error)
        urls.each { |url|
          @notification_by_url = @notifications.select do |n|
            n.callback_url.eql? url
          end.map(&:id)
          described_class.new.perform(url, @notification_by_url, Registrations::MAX_RETRIES)
        }
        @notifications.each do |notification_row|
          notification_row.reload
          expect(notification_row.final_attempt_id).to be nil
          wnaa = WebhookNotificationAttemptAssoc.where(webhook_notification_id: notification_row.id)
          wnaa.each do |w|
            attempt = WebhookNotificationAttempt.find_by(id: w.webhook_notification_attempt_id)
            expect(attempt.success).to be false
            expect(attempt.response['exception'].eql? 'busted')
          end
        end
      end
    end
  end
end