# frozen_string_literal: true

require 'rails_helper'
require_dependency './lib/webhooks/utilities'

describe Webhooks::Subscription, type: :model do
  let(:consumer_id) { 'f7d83733-a047-413b-9cce-e89269dcb5b1' }
  let(:consumer_name) { 'tester' }
  let(:api_id) { SecureRandom.uuid }
  let(:api_id_invalid) { SecureRandom.uuid }
  let(:fixture_path) { './modules/vba_documents/spec/fixtures/subscriptions/' }
  let(:observers) { JSON.parse File.read("#{fixture_path}subscriptions.json") }
  # let(:event) do VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT end

  before do
    @subscription_guid = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers, api_id)
    @subscription_no_guid = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers, nil)
  end

  it 'records the subscription' do
    expect(@subscription_guid.events).to eq(observers)
    expect(@subscription_no_guid.events).to eq(observers)
  end

  it 'records the api name' do
    api_name = Webhooks::Utilities.event_to_api_name[observers['subscriptions'].first['event']]
    expect(@subscription_guid.api_name).to eq(api_name)
    expect(@subscription_no_guid.api_name).to eq(api_name)
  end

  it 'records the consumer name' do
    expect(@subscription_guid.consumer_name).to eq(consumer_name)
    expect(@subscription_no_guid.consumer_name).to eq(consumer_name)
  end

  it 'records the consumer id' do
    expect(@subscription_guid.consumer_id).to eq(consumer_id)
    expect(@subscription_no_guid.consumer_id).to eq(consumer_id)
  end

  it 'queries for subscriptions correctly' do
    api_name = Webhooks::Utilities.event_to_api_name[observers['subscriptions'].first['event']]
    query_results = Webhooks::Subscription.get_notification_urls(
      api_name:, consumer_id:, event: observers['subscriptions'].first['event'], api_guid: api_id
    )
    observer_urls = []
    observers['subscriptions'].each do |subscription|
      observer_urls << subscription['urls']
    end
    observer_urls = observer_urls.flatten.uniq

    query_results_nil = Webhooks::Subscription.get_notification_urls(
      api_name:, consumer_id:, event: observers['subscriptions'].first['event'], api_guid: nil
    )

    expect(query_results).to eq(observer_urls)
    expect(query_results_nil).to eq(observer_urls)
  end

  it 'queries for observers by guid correctly' do
    api_name = Webhooks::Utilities.event_to_api_name[observers['subscriptions'].first['event']]
    query_results = Webhooks::Subscription.get_observers_by_guid(
      api_name:, consumer_id:, api_guid: api_id
    )
    query_results_empty = Webhooks::Subscription.get_observers_by_guid(
      api_name:, consumer_id:, api_guid: api_id_invalid
    )

    expect(query_results).to eq(observers['subscriptions'])
    expect(query_results_empty).to eq([])
  end
end
