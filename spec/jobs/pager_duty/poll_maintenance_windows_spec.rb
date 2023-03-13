# frozen_string_literal: true

require 'rails_helper'
require 'pager_duty/poll_maintenance_windows'

RSpec.describe PagerDuty::PollMaintenanceWindows, type: :job do
  let(:client_stub) { instance_double('PagerDuty::MaintenanceClient') }
  let(:maint_hash) { FactoryBot.build(:maintenance_hash) }
  let(:maint_hash_updated) { FactoryBot.build(:maintenance_hash_updated) }
  let(:maint_hash_multi1) { FactoryBot.build(:maintenance_hash_multi1) }
  let(:maint_hash_multi2) { FactoryBot.build(:maintenance_hash_multi2) }
  let(:maint_hash_message) { FactoryBot.build(:maintenance_hash_with_message) }

  before do
    allow(PagerDuty::MaintenanceClient).to receive(:new) { client_stub }
  end

  after do
    MaintenanceWindow.delete_all
  end

  context 'with valid maintenance window data' do
    it 'handles empty list of windows' do
      allow(client_stub).to receive(:get_all).and_return([])
      described_class.new.perform
    end

    it 'adds entries to database' do
      allow(client_stub).to receive(:get_all).and_return([maint_hash])
      described_class.new.perform
      expect(MaintenanceWindow.find_by(pagerduty_id: 'ABCDEF')).not_to be_nil
    end

    it 'updates existing entries' do
      allow(client_stub).to receive(:get_all).and_return([maint_hash], [maint_hash_updated])
      described_class.new.perform
      original = MaintenanceWindow.find_by(pagerduty_id: 'ABCDEF')
      expect(original).not_to be_nil
      expect(original.description).to eq('')
      original_time = original.end_time
      described_class.new.perform
      updated = MaintenanceWindow.find_by(pagerduty_id: 'ABCDEF')
      expect(updated.description).to eq('')
      updated_time = updated.end_time
      expect(updated_time).to be > original_time
    end

    it 'handles duplicate external IDs' do
      allow(client_stub).to receive(:get_all).and_return([maint_hash_multi1, maint_hash_multi2])
      described_class.new.perform
      expect(MaintenanceWindow.where(pagerduty_id: 'ABC123').count).to eq(2)
    end

    it 'deletes obsolete entries' do
      Timecop.freeze(Date.new(2017, 12, 19)) do
        allow(client_stub).to receive(:get_all).and_return([maint_hash, maint_hash_multi1], [maint_hash_multi1])
        described_class.new.perform
        expect(MaintenanceWindow.find_by(pagerduty_id: 'ABCDEF')).not_to be_nil
        expect(MaintenanceWindow.find_by(pagerduty_id: 'ABC123')).not_to be_nil
        described_class.new.perform
        expect(MaintenanceWindow.find_by(pagerduty_id: 'ABCDEF')).to be_nil
        expect(MaintenanceWindow.find_by(pagerduty_id: 'ABC123')).not_to be_nil
      end
    end

    it 'deletes all obsolete entries for an external ID' do
      Timecop.freeze(Date.new(2017, 12, 19)) do
        allow(client_stub).to receive(:get_all).and_return([maint_hash, maint_hash_multi1, maint_hash_multi2],
                                                           [maint_hash])
        described_class.new.perform
        expect(MaintenanceWindow.find_by(pagerduty_id: 'ABCDEF')).not_to be_nil
        expect(MaintenanceWindow.where(pagerduty_id: 'ABC123').count).to eq(2)
        described_class.new.perform
        expect(MaintenanceWindow.find_by(pagerduty_id: 'ABCDEF')).not_to be_nil
        expect(MaintenanceWindow.where(pagerduty_id: 'ABC123').count).to eq(0)
      end
    end

    it 'extracts the user-facing message correctly' do
      allow(client_stub).to receive(:get_all).and_return([maint_hash_message])
      described_class.new.perform
      window = MaintenanceWindow.find_by(pagerduty_id: 'ABCDEF')
      expect(window).not_to be_nil
      expect(window.description).to eq('Sorry, EMIS is unavailable RN\nTry again later')
    end
  end

  context 'with error response from client' do
    before do
      allow(Settings.sentry).to receive(:dsn).and_return('asdf')
    end

    it 'bails on backend error' do
      expect(client_stub).to receive(:get_all).and_raise(Common::Exceptions::BackendServiceException)
      expect(Raven).to receive(:capture_exception).with(Common::Exceptions::BackendServiceException, level: 'error')

      described_class.new.perform
    end

    it 'bails on client error' do
      expect(client_stub).to receive(:get_all).and_raise(Common::Client::Errors::ClientError)
      expect(Raven).to receive(:capture_exception).with(Common::Client::Errors::ClientError, level: 'error')

      described_class.new.perform
    end
  end
end
