# frozen_string_literal: true

# require './spec/lib/webhooks/utilities_helper'
require 'rails_helper'
require './spec/workers/webhooks/job_tracking'

RSpec.describe Webhooks::SchedulerJob, type: :job do
  before do
    Thread.current['job_ids'] = []
  end

  it 'schedules notification jobs' do
    Webhooks::Utilities
      .register_events('gov.va.developer.SchedulerJobTEST1',
                       api_name: 'SchedulerJobTEST1', max_retries: 1) do
      future
    end
    results = Webhooks::SchedulerJob.new.perform
    results.each_with_index do |r, i|
      expect(r.first.respond_to?(:to_f)).to be true # our callbacks are intervals (for sidekiq's perform_in)
      expect(r.last).to eq Thread.current['job_ids'][i] # We get our job IDs back
    end
  end

  it 'reschedules itself when something goes wrong' do
    Webhooks::Utilities
      .register_events('gov.va.developer.SchedulerJobTEST2',
                       api_name: 'SchedulerJobTEST2', max_retries: 1) do
      future
    end
    allow_any_instance_of(Webhooks::SchedulerJob).to receive(:go).and_raise('busted')
    results = Webhooks::SchedulerJob.new.perform
    expect(results).to eq Thread.current['job_ids'].first
  end

  it 'schedules the notification job correctly' do
    future = 10.minutes.from_now
    Webhooks::Utilities
      .register_events('gov.va.developer.SchedulerJobTEST3',
                       api_name: 'SchedulerJobTEST3', max_retries: 1) do
      future
    end
    results = Webhooks::SchedulerJob.new.perform('SchedulerJobTEST3').first
    expect(results.first).to eq(future)
    expect(results.last).to eq Thread.current['job_ids'].first
  end

  it 'schedules a notification job even if the registered block fails' do
    Webhooks::Utilities
      .register_events('gov.va.developer.SchedulerJobTEST4',
                       api_name: 'SchedulerJobTEST4', max_retries: 1) do
      raise 'I am a naughty developer!'
    end
    results = Webhooks::SchedulerJob.new.perform('SchedulerJobTEST4').first
    expect(results.first.to_i).to be >= 1.hour.from_now.to_i
    expect(results.last).to eq Thread.current['job_ids'].first
  end

  it 'logs if sidekiq can not schedule the notification job' do
    allow(Webhooks::NotificationsJob).to receive(:perform_in).and_raise('busted')
    results = Webhooks::SchedulerJob.new.perform
    expect(results.flatten.include?(nil)).to be true
  end
end
