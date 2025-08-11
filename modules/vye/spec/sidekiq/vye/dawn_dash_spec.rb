# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::DawnDash, type: :worker do
  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

  it 'enqueues child jobs' do
    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain

    expect(Vye::DawnDash::ActivateBdn).to have_enqueued_sidekiq_job
  end

  context 'with disabled flipper set' do
    before do
      allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(true)
    end

    it 'does not do any processing' do
      expect(Vye::DawnDash::ActivateBdn).not_to receive(:perform_async)
      described_class.new.perform
    end
  end
end
