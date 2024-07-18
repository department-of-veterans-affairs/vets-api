# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

describe Vye::DawnDash::ActivateBdn, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  it 'enqueues child jobs' do
    expect(Vye::BdnClone).to receive(:activate_injested!)

    expect do
      described_class.perform_async
    end.to change { Sidekiq::Worker.jobs.size }.by(1)

    described_class.drain

    expect(Vye::DawnDash::EgressUpdates).to have_enqueued_sidekiq_job
  end
end
