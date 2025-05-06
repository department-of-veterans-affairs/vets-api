# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::SundownSweep, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  it 'enqueues child jobs' do
    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain

    expect(Vye::SundownSweep::ClearDeactivatedBdns).to have_enqueued_sidekiq_job
    expect(Vye::SundownSweep::DeleteProcessedS3Files).to have_enqueued_sidekiq_job
  end

  # Exceptions are tested one by one rather than all at once because it's easier to debug
  # if one of them is broken rather than trying to figure out which one in the loop is broken.
  describe 'exception handling' do
    let(:s3_client) { Aws::S3::Client.new(stub_responses: true) }
    let(:logger) { Rails.logger }

    before do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(logger).to receive(:error)
    end

    it 'throws an exception when the bucket cannot be found on AWS' do
      allow(s3_client).to receive(:delete_object)
        .and_raise(Aws::S3::Errors::NoSuchBucket.new(nil, 'NoSuchBucket'))

      expect(logger).to receive(:error).with(/NoSuchBucket/)
      expect do
        Vye::SundownSweep::DeleteProcessedS3Files.new.perform
      end.to raise_error(Aws::S3::Errors::NoSuchBucket)
    end

    it 'throws an exception when the key cannot be found on AWS' do
      allow(s3_client).to receive(:delete_object)
        .and_raise(Aws::S3::Errors::NoSuchKey.new(nil, 'NoSuchKey'))

      expect(logger).to receive(:error).with(/NoSuchKey/)
      expect do
        Vye::SundownSweep::DeleteProcessedS3Files.new.perform
      end.to raise_error(Aws::S3::Errors::NoSuchKey)
    end

    it 'throws an exception when access is denied' do
      allow(s3_client).to receive(:delete_object)
        .and_raise(Aws::S3::Errors::AccessDenied.new(nil, 'AccessDenied'))

      expect(logger).to receive(:error).with(/AccessDenied/)
      expect do
        Vye::SundownSweep::DeleteProcessedS3Files.new.perform
      end.to raise_error(Aws::S3::Errors::AccessDenied)
    end

    it 'throws an exception there is an error with the service' do
      allow(s3_client).to receive(:delete_object)
        .and_raise(Aws::S3::Errors::ServiceError.new(nil, 'ServiceError'))

      expect(logger).to receive(:error).with(/ServiceError/)
      expect do
        Vye::SundownSweep::DeleteProcessedS3Files.new.perform
      end.to raise_error(Aws::S3::Errors::ServiceError)
    end
  end
end
