# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::MidnightRun::IngressBdn, type: :worker do
  it 'checks the existence of described_class' do
    expect(Vye::BatchTransfer::IngressFiles).to receive(:bdn_load)

    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    Sidekiq::Worker.drain_all
  end
end
