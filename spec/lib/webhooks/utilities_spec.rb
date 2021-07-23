# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::Utilities' do

  let(:observers) {
    {
        "subscriptions" => [
            {
                "event" => 'test_event',
                "urls" => [
                    "https://i/am/listening",
                    "https://i/am/also/listening"
                ]
            }
        ]
    }
  }

  let(:registration) {
    ->() do
      Webhooks::Utilities.register_events('test_event',
                                          api_name: 'testing', max_retries: 3) do
        'working!'
      end
    end
  }

  before do
    Thread.current['under_test'] = true
    load './lib/webhooks/utilities.rb'
    class TestHelper
      include Webhooks::Utilities
    end
  end

  after do
    Object.send(:remove_const, :Webhooks)
  end

  it 'registers events and blocks' do
    module Testing
      include Webhooks::Utilities
      EVENTS = %w(event1 event2 event3)
      register_events(*EVENTS,
                      api_name: 'PLAY_API', max_retries: 3) do
        'working!'
      end
    end
    expect(Webhooks::Utilities.supported_events.length).to be Testing::EVENTS.length
    Testing::EVENTS.each do |e|
      expect(Webhooks::Utilities.supported_events.include?(e)).to be true
      expect(Webhooks::Utilities.event_to_api_name[e]).to be 'PLAY_API'
    end
    expect(Webhooks::Utilities.api_name_to_time_block['PLAY_API'].call).to be 'working!'
    expect(Webhooks::Utilities.api_name_to_retries['PLAY_API']).to be 3
  end

  it 'does not allow over registration' do
    registration.call
    event_spans_api = -> do
      Webhooks::Utilities.register_events('test_event',
                                          api_name: 'OTHER_API', max_retries: 3) do
        'working!'
      end
    end
    api_duplicated = -> do
      Webhooks::Utilities.register_events('other_event',
                                          api_name: 'PLAY_API', max_retries: 3) do
        'working!'
      end
    end
    expect do
      event_spans_api.call
    end.to raise_error
    expect do
      api_duplicated.call
    end.to raise_error
  end

  # assumes subscription has been validated
  it 'fetches all events from a subscription' do
    events = Webhooks::Utilities.fetch_events(observers)
    expect(events.length).to be 1
    expect(events.include?('test_event')).to be true
  end

  it 'allows valid subscriptions' do
    registration.call
    subscription = TestHelper.new.validate_subscription(observers)
    expect(subscription).to be observers
  end

  it 'does not allow invalid subscriptions' do
    registration.call
    expect do
      TestHelper.new.validate_subscription({invalid: :stuff})
    end.to raise_error
  end

  it 'detects invalid events' do
    registration.call
    observers['subscriptions'].first['event'] = 'bad_event'
    expect do
      TestHelper.new.validate_events(observers)
    end.to raise_error(/Invalid/)
  end

  it 'detects duplicate events' do
    registration.call
    duplicate = observers['subscriptions'].first.deep_dup
    observers['subscriptions'] << duplicate
    expect do
      TestHelper.new.validate_events(observers)
    end.to raise_error(/Duplicate/)
  end

end