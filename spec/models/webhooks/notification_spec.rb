# frozen_string_literal: true

require 'rails_helper'
require_dependency './lib/webhooks/utilities'

describe Webhooks::Notification, type: :model do
  let(:consumer_id) { 'f7d83733-a047-413b-9cce-e89269dcb5b1' }
  let(:consumer_name) { 'tester' }
  let(:api_id) { SecureRandom.uuid }
  let(:event) { VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT }
  let(:msg) do
    { 'msg' => 'the message' }
  end
  let(:fixture_path) { './modules/vba_documents/spec/fixtures/subscriptions/' }
  let(:observers) { JSON.parse File.read("#{fixture_path}subscriptions.json") }

  before do
    @subscription = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers, api_id)
    @notifications = Webhooks::Utilities.record_notifications(
      consumer_id:,
      consumer_name:,
      event:,
      api_guid: api_id,
      msg:
    )
  end

  it 'returns a notification per url' do
    urls = observers['subscriptions'].select { |s| s['event'].eql? event }.first['urls']
    expect(@notifications.length).to eq(urls.length)
    expect(@notifications.map(&:callback_url) - urls).to eq([])
  end

  it 'records the api name' do
    api_name = Webhooks::Utilities.event_to_api_name[event]
    @notifications.each do |notification|
      expect(notification.api_name).to eq(api_name)
    end
  end

  it 'records the consumer name' do
    @notifications.each do |notification|
      expect(notification.consumer_name).to eq(consumer_name)
    end
  end

  it 'records the consumer id' do
    @notifications.each do |notification|
      expect(notification.consumer_id).to eq(consumer_id)
    end
  end

  it 'records the event' do
    @notifications.each do |notification|
      expect(notification.event).to eq(event)
    end
  end

  it 'records the message' do
    @notifications.each do |notification|
      expect(notification.msg).to eq(msg)
    end
  end
end
