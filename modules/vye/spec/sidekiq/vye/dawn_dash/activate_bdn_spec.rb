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

  describe 'logging' do
    before do
      create(:vye_bdn_clone_base, is_active: false)
    end

    include_examples 'logging behavior', [
      { log_level: :info, text: 'Vye::DawnDash::ActivateBdn starting' },
      { log_level: :info, text: 'Vye::BdnClone.activate_injested! starting' },
      { log_level: :info, text: 'Vye::DawnDash::ActivateBdn EgressUpdates starting (async)' },
      { log_level: :info, text: 'Vye::DawnDash::ActivateBdn finished' }
    ]
  end
end
