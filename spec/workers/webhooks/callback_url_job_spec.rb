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
    @notification_by_url = -> (url) do
        @notifications.select do |n|
          n.callback_url.eql?(url)
        end.map(&:id)
      end

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
      described_class.new.perform(url, @notification_by_url.call(url), Registrations::MAX_RETRIES)
    }
    @notifications.each do |notification_row|
      notification_row.reload
      expect(notification_row.final_attempt_id).to be_an(Integer)
      attempt = notification_row.final_attempt
      expect(attempt.success).to be true
      expect(attempt.response['status']).to be 200
    end

  end

  context 'failures' do

    it 'records failure attempts from a responsive callback url' do
      mock_faraday(400, '', false)
      urls.each { |url|
        described_class.new.perform(url, @notification_by_url.call(url), Registrations::MAX_RETRIES)
      }
      @notifications.each do |notification_row|
        notification_row.reload
        expect(notification_row.final_attempt_id).to be nil
        expect(notification_row.final_attempt).to be nil
        wna = notification_row.webhook_notification_attempts
        expect(wna.count).to be 1
        attempt = wna.first
        expect(attempt.success).to be false
        expect(attempt.response['status']).to be 400
      end
    end

    it 'the final attempt id is set if we fail max retries and we try max retries' do
      mock_faraday(400, '', false)
      max_retries = Registrations::MAX_RETRIES
      urls.each { |url|
        max_retries.times do
          described_class.new.perform(url, @notification_by_url.call(url), max_retries)
        end
      }
      @notifications.each do |notification_row|
        notification_row.reload
        expect(notification_row.final_attempt_id).to be_an(Integer)
        expect(notification_row.webhook_notification_attempts.count).to be max_retries
        attempt = notification_row.final_attempt
        expect(attempt.success).to be false
        expect(attempt.response['status']).to be 400
      end
    end

    it 'records failure attempts from an unresponsive callback url' do
      [Faraday::ClientError.new('busted'), StandardError.new('busted')].each do |error|
        # standard error forces exercise of last exception block
        allow(Faraday).to receive(:post).and_raise(error)
        urls.each { |url|
          described_class.new.perform(url, @notification_by_url.call(url), Registrations::MAX_RETRIES)
        }
        @notifications.each do |notification_row|
          notification_row.reload
          expect(notification_row.final_attempt_id).to be nil
          wna = notification_row.webhook_notification_attempts
          wna.each do |attempt|
            expect(attempt.success).to be false
            expect(attempt.response['exception'].eql? 'busted')
          end
        end
      end
    end
  end
end
