# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/job_metadata_middleware'
require 'sidekiq/job_metadata'

class TestWorker
  include Sidekiq::Worker
end

class TestWorkerWithJobMetadata < TestWorker
  include Sidekiq::JobMetadata
end

RSpec.describe Sidekiq::JobMetadataMiddleware do
  let(:middleware) { described_class.new }
  let(:job) { { 'jid' => '12345', 'class' => 'MyWorker' } }
  let(:queue) { 'default' }

  it 'sets the @job_metadata instance variable for workers with job metadata' do
    worker = TestWorkerWithJobMetadata.new

    middleware.call(worker, job, queue) do
      expect(worker.instance_variable_get(:@job_metadata)).to eq(job)
    end
  end

  it 'does not set @sidekiq_job for workers without metadata' do
    worker = TestWorker.new

    middleware.call(worker, job, queue) do
      expect(worker.instance_variable_get(:@job_metadata)).to be_nil
    end
  end
end
