# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'
require 'timecop'

describe Vye::DawnDash::EgressUpdates, type: :worker do
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

    it 'checks the existence of described_class' do
      expect(Vye::BatchTransfer::EgressFiles).to receive(:address_changes_upload)
      expect(Vye::BatchTransfer::EgressFiles).to receive(:direct_deposit_upload)
      expect(Vye::BatchTransfer::EgressFiles).to receive(:verification_upload)
      expect(Vye::BdnClone).to receive(:clear_export_ready!)

      expect do
        described_class.perform_async
      end.to change { Sidekiq::Worker.jobs.size }.by(1)

      described_class.drain
    end
  end

  context 'when it is a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 4)) # Independence Day
    end

    after do
      Timecop.return
    end

    it 'does not process egress updates' do
      expect(Vye::BatchTransfer::EgressFiles).not_to receive(:address_changes_upload)
      expect(Vye::BatchTransfer::EgressFiles).not_to receive(:direct_deposit_upload)
      expect(Vye::BatchTransfer::EgressFiles).not_to receive(:verification_upload)
      expect(Vye::BdnClone).not_to receive(:clear_export_ready!)

      expect do
        described_class.new.perform
      end.not_to(change { Sidekiq::Worker.jobs.size })
    end
  end
end
