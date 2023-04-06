# frozen_string_literal: true

# require './spec/lib/webhooks/utilities_helper'
require 'rails_helper'
require './lib/webhooks/utilities'

RSpec.describe 'Webhooks::Utilities' do
  let(:observers) do
    {
      'subscriptions' => [
        {
          'event' => 'test_event',
          'urls' => [
            'https://i/am/listening',
            'https://i/am/also/listening'
          ]
        }
      ]
    }
  end

  before(:all) do
    class TestHelper
      include Webhooks::Utilities
    end
    Webhooks::Utilities.register_events('test_event',
                                        api_name: 'TEST_API', max_retries: 3) do
      'working!'
    end
  end

  it 'registers events and blocks' do
    module Testing
      include Webhooks::Utilities
      LIB_EVENTS = %w[event1 event2 event3].freeze
      register_events(*LIB_EVENTS,
                      api_name: 'TEST_API2', max_retries: 3) do
        'working!'
      end
    end
    # total_events = Testing::EVENTS.length + 1
    # initial registration in before block adds one
    # expect(Webhooks::Utilities.supported_events.length).to be(total_events)
    # Above test on the build server gets hard to do if another tests causes a registration.  We check each event...
    Testing::LIB_EVENTS.each do |e|
      expect(Webhooks::Utilities.supported_events.include?(e)).to be true
      expect(Webhooks::Utilities.event_to_api_name[e]).to be 'TEST_API2'
    end
    expect(Webhooks::Utilities.api_name_to_time_block['TEST_API2'].call).to be 'working!'
    expect(Webhooks::Utilities.api_name_to_retries['TEST_API2']).to be 3
  end

  it 'does not allow over registration' do
    event_spans_api = lambda do
      Webhooks::Utilities.register_events('test_event', api_name: 'OTHER_API', max_retries: 3) do
        'working!'
      end
    end
    api_duplicated = lambda do
      Webhooks::Utilities.register_events('other_event', api_name: 'TEST_API', max_retries: 3) do
        'working!'
      end
    end
    expect do
      event_spans_api.call
    end.to raise_error(ArgumentError)
    expect do
      api_duplicated.call
    end.to raise_error(ArgumentError)
  end

  # assumes subscription has been validated
  it 'fetches all events from a subscription' do
    events = Webhooks::Utilities.fetch_events(observers)
    expect(events.length).to be 1
    expect(events.include?('test_event')).to be true
  end

  it 'allows valid subscriptions' do
    subscription = TestHelper.new.validate_subscription(observers)
    expect(subscription).to be observers
  end

  it 'does not allow invalid subscriptions' do
    expect do
      TestHelper.new.validate_subscription({ invalid: :stuff })
    end.to raise_error(StandardError)
  end

  # rubocop:disable Style/MultilineBlockChain
  it 'detects invalid events' do
    observers['subscriptions'].first['event'] = 'bad_event'
    expect do
      TestHelper.new.validate_events(observers['subscriptions'])
    end.to raise_error do |e|
      expect(e.errors.first.detail).to match(/^invalid/i)
    end
  end

  it 'detects duplicate events' do
    duplicate = observers['subscriptions'].first.deep_dup
    observers['subscriptions'] << duplicate
    expect do
      TestHelper.new.validate_events(observers['subscriptions'])
    end.to raise_error do |e|
      expect(e.errors.first.detail).to match(/^duplicate/i)
    end
  end

  it 'validates urls' do
    with_settings(Settings.webhooks, require_https: false) do
      expect(TestHelper.new.validate_url('http://www.google.com')).to be true
    end
    expect do
      TestHelper.new.validate_url('Not a good url')
    end.to raise_error do |e|
      expect(e.errors.first.detail).to match(/URI does not parse/)
    end
    with_settings(Settings.webhooks, require_https: true) do
      expect(TestHelper.new.validate_url('https://www.google.com')).to be true
      expect do
        TestHelper.new.validate_url('http://www.google.com')
      end.to raise_error do |e|
        expect(e.errors.first.detail).to match(/must be https/)
      end
    end
    with_settings(Settings.webhooks, require_https: false) do
      valids = ['http://www.google.com', 'https://www.google.com']
      expect(TestHelper.new.validate_urls(valids)).to be true
    end
  end
  # rubocop:enable Style/MultilineBlockChain
end
