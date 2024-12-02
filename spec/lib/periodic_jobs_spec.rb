# frozen_string_literal: true

require 'rails_helper'
require 'timecop'
require 'holidays'

RSpec.describe 'PeriodicJobs', type: :service do
  let(:mgr) { double('manager') }

  context "when it's a US holiday" do
    before do
      Timecop.freeze(Date.parse('2024-07-04')) # July 4th as a holiday
    end

    after do
      Timecop.return
    end

    it 'does not register jobs on holidays' do
      expect(mgr).not_to receive(:register)

      unless Holidays.on(Time.zone.today, :us, :observed).any?
        mgr.register('15 00 * *1-5', 'Vye::MidnightRun::IngressBdn')
        mgr.register('45 03 * *1-5', 'Vye::MidnightRun::IngressTims')
      end
    end
  end

  context "when it's a non-holiday weekday" do
    before do
      Timecop.freeze(Date.parse('2024-02-15')) # A non-holiday weekday
    end

    after do
      Timecop.return
    end

    it 'registers jobs on non-holiday weekdays' do
      expect(mgr).to receive(:register).twice

      unless Holidays.on(Time.zone.today, :us, :observed).any?
        mgr.register('15 00 * *1-5', 'Vye::MidnightRun::IngressBdn')
        mgr.register('45 03 * *1-5', 'Vye::MidnightRun::IngressTims')
      end
    end
  end
end
