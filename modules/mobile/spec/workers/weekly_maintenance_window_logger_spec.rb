# frozen_string_literal: true

require 'rails_helper'
require 'date'

RSpec.describe Mobile::V0::WeeklyMaintenanceWindowLogger, type: :job do
  after { Timecop.return }

  describe '#perform' do
    before do
      FactoryBot.create(:mobile_maintenance_evss)
      FactoryBot.create(:mobile_maintenance_mpi)
      FactoryBot.create(:mobile_maintenance_dslogon)
    end

    context 'When maintenance windows have been created within the last week' do
      before do
        Timecop.freeze(Time.zone.parse('2021-05-29 21:33:39'))
      end

      it 'Logs maintenance windows' do
        expect(Rails.logger).to receive(:info).with('Mobile - Maintenance Windows', anything)
        described_class.new.perform
      end
    end

    context 'When maintenance windows have NOT been created within the last week' do
      before do
        Timecop.freeze(Time.zone.parse('2021-06-02 21:33:39'))
      end

      it 'does NOT log maintenance windows' do
        expect(Rails.logger).not_to receive(:info).with('Mobile - Maintenance Windows', anything)
        described_class.new.perform
      end
    end
  end
end
