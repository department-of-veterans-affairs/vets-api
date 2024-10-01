# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/job_metadata_middleware'
require 'sidekiq/job_metadata'

class TestJob
  include Sidekiq::Job
end

class TestJobWithJobMetadata < TestJob
  include Sidekiq::JobMetadata
end

RSpec.describe Sidekiq::JobMetadataMiddleware do
  let(:middleware) { described_class.new }
  let(:job_payload) { { 'jid' => '12345', 'class' => 'MyJob' } }
  let(:queue) { 'default' }

  it 'sets the @job_metadata instance variable for jobs with job metadata' do
    job_instance = TestJobWithJobMetadata.new

    middleware.call(job_instance, job_payload, queue) do
      expect(job_instance.instance_variable_get(:@job_metadata)).to eq(job_payload)
    end
  end

  it 'does not set @sidekiq_job for jobs without metadata' do
    job_instance = TestJob.new

    middleware.call(job_instance, job_payload, queue) do
      expect(job_instance.instance_variable_get(:@job_metadata)).to be_nil
    end
  end
end
