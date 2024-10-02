# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::SundownSweep::DeleteProcessedS3Files, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  it 'checks the existence of described_class' do
    expect(Vye::CloudTransfer).to receive(:remove_aws_files_from_s3_buckets)

    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain
  end
end
