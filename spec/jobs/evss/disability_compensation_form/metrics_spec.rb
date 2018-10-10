# frozen_string_literal: true

require 'rails_helper'

describe EVSS::DisabilityCompensationForm::Metrics do
  let(:job_prefix) { 'job.prefix' }
  let(:jid) { SecureRandom.uuid }

  subject { described_class.new('job.prefix', jid) }

  describe '#increment_try' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with("#{job_prefix}.try", tags: ["job_id:#{jid}"])
      subject.increment_try
    end
  end

  describe '#increment_success' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with("#{job_prefix}.success", tags: ["job_id:#{jid}"])
      subject.increment_success
    end
  end

  describe '#increment_non_retryable' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with(
        "#{job_prefix}.non_retryable_error",
        tags: ['error:StandardError', "job_id:#{jid}", 'message:non retryable']
      )
      subject.increment_non_retryable(StandardError.new('non retryable'))
    end
  end

  describe '#increment_retryable' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with(
        "#{job_prefix}.retryable_error",
        tags: ['error:StandardError', "job_id:#{jid}", 'message:retryable']
      )
      subject.increment_retryable(StandardError.new('retryable'))
    end
  end

  describe '#increment_exhausted' do
    it 'increments a statsd counter' do
      expect(StatsD).to receive(:increment).with("#{job_prefix}.exhausted", tags: ["job_id:#{jid}"])
      subject.increment_exhausted
    end
  end
end
