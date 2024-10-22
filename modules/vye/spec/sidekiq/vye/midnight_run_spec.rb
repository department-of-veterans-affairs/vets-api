# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::MidnightRun, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  it 'enqueues child jobs' do
    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain

    expect(Vye::MidnightRun::IngressBdn).to have_enqueued_sidekiq_job
  end

  describe 'logging' do
    include_examples 'logging behavior', [
      { log_level: :info, text: 'Vye::MidnightRun starting' },
      { log_level: :info, text: 'Vye::MidnightRun finished' }
    ]
  end
end
