# frozen_string_literal: true

require 'rails_helper'
Thread.current['under_test'] = true
load './lib/webhooks/utilities.rb'
load './app/models/webhooks/utilities.rb'


describe Webhooks::Utilities, type: :model do

  let(:consumer_id) do 'f7d83733-a047-413b-9cce-e89269dcb5b1' end
  let(:consumer_name) do 'tester' end
  let(:api_id) do '43581f6f-448c-4ed3-846a-68a004c9b78b' end
  let(:msg) do
    {'msg' => 'the message'}
  end
  let(:observers) {
    {
        "subscriptions" => [
            {
                "event" => 'model_event',
                "urls" => [
                    "https://i/am/listening",
                    "https://i/am/also/listening"
                ]
            }
        ]
    }
  }


  before(:all) do
    #load dependent models
    load './app/models/webhooks/notification.rb'
    load './app/models/webhooks/subscription.rb'
    # load './lib/webhooks/utilities.rb'
    # load './app/models/webhooks/utilties.rb'
    module Testing
      include Webhooks::Utilities
      EVENTS = %w(model_event)
      register_events(*EVENTS,
                      api_name: 'MODEL_TESTING', max_retries: 3) do
        'working!'
      end
    end
    Webhooks::Subscription.destroy_all
    Webhooks::Notification.destroy_all
  end

  after(:all) do
    Object.send(:remove_const, :Webhooks) # clean up between runs in a rails console
  end

  before(:each) do

  end

  it 'builds subscriptions' do
    subscription = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers, api_id)
    expect(subscription.first.id.nil?).to be false
  end

  it 'records notifications' do
    # # get the message to record the status change web hook
    Webhooks::Utilities.record_notification(
        consumer_id: consumer_id,
        consumer_name: consumer_name,
        event: Testing::EVENTS.first,
        api_guid: api_id,
        msg: msg
    )
    expect(Webhooks::Notification.where(api_guid: api_id).count).to be 2
  end

end