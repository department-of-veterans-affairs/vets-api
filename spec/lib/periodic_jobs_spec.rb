# frozen_string_literal: true

require 'rails_helper'
require 'timecop'
require 'holidays'

RSpec.describe 'PeriodicJobs', type: :job do
  let(:mgr) { MockJobManager.new }

  before do
    # Temporarily replace the PERIODIC_JOBS constant with a new lambda for testing
    stub_const('PERIODIC_JOBS', lambda { |manager|
      manager.tz = ActiveSupport::TimeZone.new('America/New_York')
      load Rails.root.join('lib', 'periodic_jobs.rb').to_s
      # Call the original PERIODIC_JOBS lambda with our mock manager
      require_relative 'lib/periodic_jobs'
      PERIODIC_JOBS.call(manager)
    })

    allow(ActiveSupport::TimeZone).to receive(:new).with('America/New_York').and_return(Time.zone)
  end

  context 'on a non-holiday weekday' do
    before do
      Timecop.freeze(Date.new(2024, 1, 16)) # A typical weekday
      allow(Holidays).to receive(:on).and_return([])

      PERIODIC_JOBS.call(mgr)
    end

    after do
      Timecop.return
    end

    it 'registers Vye jobs on non-holiday' do
      vye_jobs = mgr.registered_jobs.select { |_, job| job.start_with?('Vye::') }
      expect(vye_jobs).not_to be_empty
    end
  end

  context 'on a federal holiday' do
    before do
      Timecop.freeze(Date.new(2024, 7, 4)) # Independence Day
      allow(Holidays).to receive(:on).with(Date.new(2024, 7, 4), :us,
                                           :observed).and_return([{ holiday: 'Independence Day' }])

      PERIODIC_JOBS.call(mgr)
    end

    after do
      Timecop.return
    end

    it 'skips Vye jobs on holiday' do
      vye_jobs = mgr.registered_jobs.select { |_, job| job.start_with?('Vye::') }
      expect(vye_jobs).to be_empty
    end
  end
end

class MockJobManager
  attr_accessor :tz
  attr_reader :registered_jobs

  def initialize
    @registered_jobs = []
  end

  def register(schedule, job_name)
    @registered_jobs << [schedule, job_name]
  end
end
