# frozen_string_literal: true

require 'rails_helper'
require_dependency './lib/webhooks/utilities'

#describe Webhook::Notification, type: model do
describe WebhookNotification, type: :model do
  let(:consumer_id) do 'f7d83733-a047-413b-9cce-e89269dcb5b1' end
  let(:consumer_name) do 'tester' end
  let(:api_id) do '43581f6f-448c-4ed3-846a-68a004c9b78b' end
  let(:event) do VBADocuments::Registrations::WEBHOOK_STATUS_CHANGE_EVENT end
  let(:msg) do
    {'msg' => 'the message'}
  end
  let(:fixture_path) { './modules/vba_documents/spec/fixtures/subscriptions/' }
  let(:observers_json) {JSON.parse File.read(fixture_path + 'subscriptions.json')}

  before do
    @subscription = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers_json, api_id)
    @notifications = Webhooks::Utilities.record_notification(
        consumer_id: consumer_id,
        consumer_name: consumer_name,
        event: event,
        api_guid: api_id,
        msg: msg
    )
  end

  it 'returns a notification per url' do
    urls = observers_json['subscriptions'].select do |s| s['event'].eql? event end.first['urls']
    expect(@notifications.length).to eq(urls.length)
    expect(@notifications.map(&:callback_url) - urls).to eq([])
  end

  # todo kevin, ignore final attempt id this will be tested by a job code spec. ignore processing
  # Ensure the columns (that are in common) between @subscription and @notifications match.  @notifications is an array
  # of notifications on per url.  So iterate and check.



end