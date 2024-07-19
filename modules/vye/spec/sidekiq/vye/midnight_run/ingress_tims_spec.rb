# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::MidnightRun::IngressTims, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  it 'checks the existence of described_class' do
    expect(Vye::BatchTransfer::IngressFiles).to receive(:tims_load)

    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain
  end
end
