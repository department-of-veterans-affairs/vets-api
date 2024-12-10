# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'
require 'timecop'

describe Vye::DawnDash::ActivateBdn, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  context 'when it is not a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 2)) # Regular work day
    end

    after do
      Timecop.return
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

  context 'when it is a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 4)) # Independence Day
    end

    after do
      Timecop.return
    end

    it 'does not activate BDNs' do
      expect(Vye::BdnClone).not_to receive(:activate_injested!)
      described_class.new.perform
    end
  end
end
