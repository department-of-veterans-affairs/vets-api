# frozen_string_literal: true

# require './spec/lib/webhooks/utilities_helper'
require 'rails_helper'
require_relative 'job_tracking'
require './lib/webhooks/utilities'
require_relative 'registrations'

RSpec.describe Webhooks::NotificationsJob, type: :job do
  let(:consumer_id) { 'f7d83733-a047-413b-9cce-e89269dcb5b1' }
  let(:consumer_name) { 'tester' }
  let(:api_id) { SecureRandom.uuid }
  let(:msg) do
    { 'msg' => 'the message' }
  end
  let(:observers_json) do
    {
      'subscriptions' => [
        {
          'event' => Registrations::TEST_EVENT,
          'urls' => [
            'https://i/am/listening',
            'https://i/am/also/listening'
          ]
        }
      ]
    }
  end

  before do
    @subscription = Webhooks::Utilities.register_webhook(consumer_id, consumer_name, observers_json, api_id)
    @notifications = Webhooks::Utilities.record_notifications(
      consumer_id:,
      consumer_name:,
      event: Registrations::TEST_EVENT,
      api_guid: api_id,
      msg:
    )
    Thread.current['job_ids'] = []
  end

  it 'schedules the scheduler job' do
    job_id = Webhooks::NotificationsJob.new.perform(Registrations::API_NAME).call
    expect(job_id.flatten.last).to eq Thread.current['job_ids'].last
  end

  it 'logs when an unexpected exception occurs' do
    allow(Webhooks::CallbackUrlJob).to receive(:perform_async).and_raise('busted')
    job_id = Webhooks::NotificationsJob.new.perform(Registrations::API_NAME)
    expect((%w[true false] - [job_id.to_s]).count).to eq 1 # the logger returns something truthy!
  end

  it 'scheduled three jobs total' do
    described_class.new.perform(Registrations::API_NAME)
    # first two jobs will be url callback jobs (note two urls in observable json map above)
    # third job is the next notification job kicked off via the scheduler job
    expect(Thread.current['job_ids'].length).to eq 3
  end

  it 'records processing time before publication attempt' do
    t = Time.zone.now
    Timecop.freeze(Time.zone.now)
    described_class.new.perform(Registrations::API_NAME)
    @notifications.each do |n|
      n.reload
      expect(n.processing).to be t.to_i
    end
    Timecop.return
  end
end
