# frozen_string_literal: true

require 'rails_helper'
require 'timecop'

describe Vye::SundownSweep::DeleteProcessedS3Files, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  context 'when it is not a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 2)) # Regular work day
    end

    after do
      Timecop.return
    end

    it 'checks the existence of described_class' do
      expect(Vye::CloudTransfer).to receive(:remove_aws_files_from_s3_buckets)

      expect do
        described_class.perform_async
      end.to change { Sidekiq::Worker.jobs.size }.by(1)

      described_class.drain
    end
  end

  context 'when it is a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 4)) # Independence Day
    end

    after do
      Timecop.return
    end

    it 'does not process S3 files' do
      expect(Vye::CloudTransfer).not_to receive(:remove_aws_files_from_s3_buckets)
      described_class.new.perform

      expect do
        described_class.new.perform
      end.not_to(change { Sidekiq::Worker.jobs.size })
    end
  end
end
