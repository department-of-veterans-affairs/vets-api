# frozen_string_literal: true

require 'rails_helper'
require_dependency './lib/webhooks/utilities'

describe Webhooks::Subscription, type: :model do
  let(:consumer_id) do 'f7d83733-a047-413b-9cce-e89269dcb5b1' end
  let(:consumer_name) do 'tester' end
  let(:api_id) do '43581f6f-448c-4ed3-846a-68a004c9b78b' end
  let(:api_id_invalid) do '11111f1f-111c-1ed1-111a-11a111c1b11b' end
  let(:fixture_path) { './modules/vba_documents/spec/fixtures/subscriptions/' }
  let(:observers) {JSON.parse File.read(fixture_path + 'subscriptions.json')}
  # let(:event) do VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT end

  before do
    @subscription_guid = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers, api_id)
    @subscription_no_guid = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers, nil)
  end

  it 'records the subscription' do
    @subscription_guid.each do |s|
      expect(s.events).to eq(observers)
    end
    @subscription_no_guid.each do |s|
      expect(s.events).to eq(observers)
    end
  end

  it 'records the api name' do
    api_name = Webhooks::Utilities.event_to_api_name[observers['subscriptions'].first['event']]
    @subscription_guid.each do |s|
      expect(s.api_name).to eq(api_name)
    end
    @subscription_no_guid.each do |s|
      expect(s.api_name).to eq(api_name)
    end
  end

  it 'records the consumer name' do
    @subscription_guid.each do |s|
      expect(s.consumer_name).to eq(consumer_name)
    end
    @subscription_no_guid.each do |s|
      expect(s.consumer_name).to eq(consumer_name)
    end
  end

  it 'records the consumer id' do
    @subscription_guid.each do |s|
      expect(s.consumer_id).to eq(consumer_id)
    end
    @subscription_no_guid.each do |s|
      expect(s.consumer_id).to eq(consumer_id)
    end
  end

  it 'queries for subscriptions correctly' do
    api_name = Webhooks::Utilities.event_to_api_name[observers['subscriptions'].first['event']]
    query_results = Webhooks::Subscription.get_notification_urls(
      api_name: api_name, consumer_id: consumer_id, event: observers['subscriptions'].first['event'], api_guid: api_id
    )
    observer_urls = []
    observers['subscriptions'].each do |subscription|
      observer_urls << subscription['urls']
    end
    observer_urls = observer_urls.flatten.uniq

    query_results_nil = Webhooks::Subscription.get_notification_urls(
      api_name: api_name, consumer_id: consumer_id, event: observers['subscriptions'].first['event'], api_guid: nil
    )

    expect(query_results).to eq(observer_urls)
    expect(query_results_nil).to eq(observer_urls)
  end

  it 'queries for observers by guid correctly' do
    api_name = Webhooks::Utilities.event_to_api_name[observers['subscriptions'].first['event']]
    query_results = Webhooks::Subscription.get_observers_by_guid(
      api_name: api_name, consumer_id: consumer_id, api_guid: api_id
    )
    query_results_empty = Webhooks::Subscription.get_observers_by_guid(
      api_name: api_name, consumer_id: consumer_id, api_guid: api_id_invalid
    )

    expect(query_results).to eq(observers['subscriptions'])
    expect(query_results_empty).to eq([])
  end


end