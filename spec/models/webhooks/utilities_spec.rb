# frozen_string_literal: true

require 'rails_helper'
require './lib/webhooks/utilities'
require './app/models/webhooks/utilities'

# use these loads when running in a rails console
# load './app/models/webhooks/notification.rb'
# load './app/models/webhooks/subscription.rb'
# load './lib/webhooks/utilities.rb'
# load './app/models/webhooks/utilities.rb'

describe Webhooks::Utilities, type: :model do
  API_NAME = 'testing'
  let(:consumer_id) { 'f7d83733-a047-413b-9cce-e89269dcb5b1' }
  let(:consumer_name) { 'tester' }
  let(:api_guid) { SecureRandom.uuid }
  let(:msg) { { 'msg' => 'the message' } }
  let(:observers) do
    {
      'subscriptions' => [
        {
          'event' => 'model_event',
          'urls' => ['https://i/am/listening', 'https://i/am/also/listening']
        },
        {
          'event' => 'model_event2',
          'urls' => ['https://i/am/listening2']
        }
      ]
    }
  end

  before(:all) do
    # load dependent models
    module Testing
      include Webhooks::Utilities
      EVENTS = %w[model_event model_event2].freeze
      register_events(*EVENTS, api_name: API_NAME, max_retries: 3) do
        'working!'
      end
    end

    # use with rails console testing
    # Webhooks::Subscription.destroy_all
    # Webhooks::Notification.destroy_all
  end

  def validate_common_columns(subscription, notifications)
    notifications.each do |n|
      expect(n.api_name.eql?(subscription.api_name)).to be true
      expect(n.consumer_id).to be subscription.consumer_id
      expect(n.consumer_name.eql?(subscription.consumer_name)).to be true
      expect(n.api_guid).to be subscription.api_guid
    end
  end

  it 'builds a webhook subscription and writes notifications' do
    subscription = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers, api_guid)
    rowcount = Webhooks::Subscription.count
    expect(rowcount).to be 1
    expect(subscription.api_guid).to be api_guid
    expect(subscription.api_name.eql?(API_NAME)).to be true
    expect(subscription.events.eql?(observers)).to be true

    Testing::EVENTS.each do |e|
      params = { consumer_id: consumer_id, consumer_name: consumer_name, event: e, api_guid: api_guid, msg: msg }
      notifications = Webhooks::Utilities.record_notifications(**params)
      validate_common_columns(subscription, notifications)
      urls = notifications.map(&:callback_url)

      if e.eql? Testing::EVENTS.first
        expect(notifications.count).to be 2
        expect(notifications.first.event.eql?('model_event')).to be true
        expect(notifications.first.msg.eql?(msg)).to be true
        observing_urls = observers['subscriptions'].first['urls']
      else
        expect(notifications.count).to be 1
        expect(notifications.last.event.eql?('model_event2')).to be true
        observing_urls = observers['subscriptions'].last['urls']
      end
      expect((observing_urls - urls).length).to be 0
    end

    rowcount = Webhooks::Notification.count
    expect(rowcount).to be 3
  end
end
