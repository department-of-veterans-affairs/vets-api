# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/monitored_worker'

describe Sidekiq::RetryMonitoring do
  class RetryTestJob
    include Sidekiq::Worker
    include Sidekiq::MonitoredWorker

    def perform; end

    def notify(_params); end

    def retry_limits_for_notification
      [4]
    end
  end

  let(:middleware) { Sidekiq::RetryMonitoring.new }
  let(:params) do
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

  it 'calls notify after retry limit is hit' do
    params['retry_count'] = 3

    RetryTestJob.perform_async
    worker = RetryTestJob.new
    allow(worker).to receive(:notify).and_return(true)

    middleware.call(worker, params, nil) {}

    expect(worker).to have_received(:notify).with(params)
  end
end
