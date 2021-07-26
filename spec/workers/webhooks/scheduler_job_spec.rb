# frozen_string_literal: true

require 'rails_helper'
require './spec/workers/webhooks/job_tracking'

Thread.current['under_test'] = true

RSpec.describe Webhooks::SchedulerJob, type: :job do
  after do
    Thread.current['job_ids'] = []
  end

  it 'schedules notification jobs' do
    results = Webhooks::SchedulerJob.new.perform
    results.each_with_index do |r, i|
      expect(r.first.respond_to?(:to_f)).to be true # our callbacks are intervals (for sidekiq's perform_in)
      expect(r.last).to eq Thread.current['job_ids'][i] # We get our job IDs back
    end
  end

  it 'reschedules itself when something goes wrong' do
    allow_any_instance_of(Webhooks::SchedulerJob).to receive(:go).and_raise('busted')
    results = Webhooks::SchedulerJob.new.perform
    expect(results).to eq Thread.current['job_ids'].first
  end

  it 'schedules the notification job correctly' do
    future = 10.minutes.from_now
    Webhooks::Utilities
      .register_events('gov.va.developer.TEST', api_name: 'TEST', max_retries: 1) do |_t|
      future
    end
    results = Webhooks::SchedulerJob.new.perform('TEST').first
    expect(results.first).to eq(future)
    expect(results.last).to eq Thread.current['job_ids'].first
  end

  it 'schedules a notification job even if the registered block fails' do
    Webhooks::Utilities
      .register_events('gov.va.developer.TEST2', api_name: 'TEST2', max_retries: 1) do |_t|
      raise 'I am a naughty developer!'
    end
    results = Webhooks::SchedulerJob.new.perform('TEST2').first
    expect(results.first.to_i).to be >= 1.hour.from_now.to_i
    expect(results.last).to eq Thread.current['job_ids'].first
  end

  it 'logs if sidekiq can not schedule the notification job' do
    allow(Webhooks::NotificationsJob).to receive(:perform_in).and_raise('busted')
    results = Webhooks::SchedulerJob.new.perform
    expect(results.flatten.include?(nil)).to be true
  end
end
