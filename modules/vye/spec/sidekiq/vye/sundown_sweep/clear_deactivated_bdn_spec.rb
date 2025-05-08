# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'
require 'timecop'

describe Vye::SundownSweep::ClearDeactivatedBdns, type: :worker do
  before do
    Sidekiq::Job.clear_all
  end

  context 'when it is not a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 2)) # Regular work day
    end

    after do
      Timecop.return
    end

    it 'checks the existence of described_class' do
      expect(Vye::CloudTransfer).to receive(:delete_inactive_bdns)

      expect do
        described_class.perform_async
      end.to change { Sidekiq::Worker.jobs.size }.by(1)

      described_class.drain
    end

    # direct deposit changes, addy changes and awards are deleted
    # verifications have their foreign keys set to null
    # We are going to keep 2 weeks worth of data except for addy & direct deposit changes to
    # track down a bug. Once we fix that, we will revert the test back to it's original state
    it 'deletes inactive BDNs and processes their ri children correctly' do
      # create one active and one inactive BDN
      create(:vye_bdn_clone_with_user_info_children, created_at_override: 15.days.ago, updated_at_override: 15.days.ago)
      create(:vye_bdn_clone_with_user_info_children)
      create(:vye_bdn_clone_with_user_info_children, :active)

      # rubocop:disable RSpec/ChangeByZero
      expect do
        described_class.new.perform
      end.to change(Vye::BdnClone, :count)
        .by(-1)
        .and change(Vye::AddressChange, :count).by(-6)
        .and change(Vye::Award, :count).by(-4)
        .and change(Vye::DirectDepositChange, :count).by(-4)
        .and change(Vye::Verification, :count).by(0)
        .and change(Vye::Verification.where(user_info_id: nil), :count).by(4)
        .and change(Vye::Verification.where(award_id: nil), :count).by(4)
        .and change(Vye::Verification.where.not(user_info_id: nil), :count).by(-4)
        .and change(Vye::Verification.where.not(award_id: nil), :count).by(-4)

      described_class.drain
      # rubocop:enable RSpec/ChangeByZero
    end

    it 'does not delete or nilify anything if there are no inactive BDNs' do
      create(:vye_bdn_clone_with_user_info_children, :active)

      # rubocop:disable RSpec/ChangeByZero
      expect do
        described_class.new.perform
      end.to change(Vye::BdnClone, :count)
        .by(-0)
        .and change(Vye::AddressChange, :count).by(0)
        .and change(Vye::Award, :count).by(0)
        .and change(Vye::DirectDepositChange, :count).by(0)
        .and change(Vye::Verification, :count).by(0)

      described_class.drain
      # rubocop:enable RSpec/ChangeByZero
    end
  end

  context 'when it is a holiday' do
    before do
      Timecop.freeze(Time.zone.local(2024, 7, 4)) # Independence Day
    end

    after do
      Timecop.return
    end

    it 'does not process deactivated BDNs' do
      expect(Vye::CloudTransfer).not_to receive(:delete_inactive_bdns)

      expect do
        described_class.new.perform
      end.not_to(change { Sidekiq::Worker.jobs.size })
    end
  end
end
