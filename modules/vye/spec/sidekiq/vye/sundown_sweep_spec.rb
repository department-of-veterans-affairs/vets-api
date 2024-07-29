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

    expect(Vye::SundownSweep::ClearDeactivatedBdn).to have_enqueued_sidekiq_job
    expect(Vye::SundownSweep::DeleteProcessedS3Files).to have_enqueued_sidekiq_job
    expect(Vye::SundownSweep::PurgesStaleVerifications).to have_enqueued_sidekiq_job
  end
end
