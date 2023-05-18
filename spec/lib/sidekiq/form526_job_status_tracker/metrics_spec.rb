# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/form526_job_status_tracker/metrics'

describe Sidekiq::Form526JobStatusTracker::Metrics do
  subject { described_class.new('job.prefix') }

  let(:job_prefix) { 'job.prefix' }

  describe '#increment_try' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with("#{job_prefix}.try")
      subject.increment_try
    end
  end

  describe '#increment_success' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with("#{job_prefix}.success",
                                                 tags: ['is_bdd:false'])
      subject.increment_success
    end
  end

  describe '#increment_non_retryable' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with(
        "#{job_prefix}.non_retryable_error",
        tags: ['error:StandardError', 'message:non retryable', 'is_bdd:false']
      )
      subject.increment_non_retryable(StandardError.new('non retryable'))
    end
  end

  describe '#increment_retryable' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with(
        "#{job_prefix}.retryable_error",
        tags: ['error:StandardError', 'message:retryable', 'is_bdd:false']
      )
      subject.increment_retryable(StandardError.new('retryable'))
    end
  end

  describe '#increment_exhausted' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with("#{job_prefix}.exhausted")
      subject.increment_exhausted
    end
  end
end
