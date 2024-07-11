# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::MidnightRun, type: :worker do
  it 'enqueues child jobs' do
    expect do
      described_class.new.perform
    end.to change { Sidekiq::Worker.jobs.size }.by(2)

    expect(Vye::MidnightRun::IngressBdn).to have_enqueued_sidekiq_job
    expect(Vye::MidnightRun::IngressTims).to have_enqueued_sidekiq_job
  end
end
