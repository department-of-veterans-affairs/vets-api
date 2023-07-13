# frozen_string_literal: true

require 'rails_helper'

class RetryTestJob
  include Sidekiq::Worker

  attr_accessor :current_retry

  def perform; end
end

describe Sidekiq::SetCurrentRetry do
  let(:worker) { RetryTestJob.new }
  let(:middleware) { Sidekiq::SetCurrentRetry.new }
  let(:job) do
    {
      'class' => 'TestJob',
      'args' => [],
      'retry' => true,
      'queue' => 'default',
      'created_at' => 1_613_662_230.2647018,
      'error_message' => '',
      'error_class' => 'RuntimeError',
      'failed_at' => 1_613_670_737.966083,
      'retry_count' => 1,
      'retried_at' => 1_613_680_062.5507782
    }
  end

  context 'on first job run' do
    it 'sets worker.current_retry to nil' do
      job['retry_count'] = nil # first job run

      allow(worker).to receive(:current_retry=)
      middleware.call(worker, job, nil) {}

      expect(worker).to have_received(:current_retry=).with(nil)
    end
  end

  context 'on first retry' do
    it 'sets worker.current_retry to 1' do
      job['retry_count'] = 0 # first retry

      allow(worker).to receive(:current_retry=)
      middleware.call(worker, job, nil) {}

      expect(worker).to have_received(:current_retry=).with(1)
    end
  end

  context 'on fifth retry' do
    it 'sets worker.current_retry to 5' do
      job['retry_count'] = 4 # fifth retry

      allow(worker).to receive(:current_retry=)
      middleware.call(worker, job, nil) {}

      expect(worker).to have_received(:current_retry=).with(5)
    end
  end
end
