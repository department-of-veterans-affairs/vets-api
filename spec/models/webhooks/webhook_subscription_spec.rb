# frozen_string_literal: true

require 'rails_helper'
require_dependency './lib/webhooks/utilities'

#describe Webhook::Subscription, type: model do
describe WebhookSubscription, type: :model do
  let(:consumer_id) do 'f7d83733-a047-413b-9cce-e89269dcb5b1' end
  let(:consumer_name) do 'tester' end
  let(:api_id) do '43581f6f-448c-4ed3-846a-68a004c9b78b' end
  let(:fixture_path) { './modules/vba_documents/spec/fixtures/subscriptions/' }
  let(:observers_json) {JSON.parse File.read(fixture_path + 'subscriptions.json')}
  # let(:event) do VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT end

  before do
    @subscription_guid = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers_json, api_id)
    @subscription_no_guid = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers_json, nil)
  end

  it 'records the subscription' do
    @subscription_guid.each do |s|
      expect(s.events).to eq(observers_json)
    end
    @subscription_no_guid.each do |s|
      expect(s.events).to eq(observers_json)
    end
  end

  it 'records the api name' do
    api_name = Webhooks::Utilities.event_to_api_name[observers_json['subscriptions'].first['event']]
    @subscription_guid.each do |s|
      expect(s.api_name).to eq(api_name)
    end
    @subscription_no_guid.each do |s|
      expect(s.api_name).to eq(api_name)
    end
  end

  # todo test for consumer_name and id
  # todo make class methods other than the first private
  # todo call get_notification_urls verify they match what is in subscriptions


end