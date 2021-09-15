# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/downtime_checker_middleware'

describe Sidekiq::DowntimeCheckerMiddleware do
  context 'when service is down' do
    it 'does not yield, but reschedules job' do
      delay = 6.hours
      allow_any_instance_of(DownTimeChecker).to receive(:down?) { delay }
      middleware = described_class.new
      worker = BGS::SubmitForm686cJob.new
      job = {}
      args = ['b6f89d130f574414b2786476f4176a6c', 73,
              { 'veteran_information' => { 'full_name' =>
              { 'first' => 'CAMERON', 'middle' => 'A', 'last' => 'TESTWOOD' },
                                           'ssn' => '125480995', 'va_file_number' => '125480995',
                                           'birth_date' => '1955-05-15' } }]
      allow(job).to receive(:[]).with('args').and_return(args)
      expect(worker).to receive(:downtime_checks).and_return([{ service_name: 'BDN', extra_delay: 0 }])
      expect(worker.class).to receive(:perform_in).with(delay, *args)

      count = 0
      middleware.call(worker, job, nil) do
        count += 1
      end
      expect(count).to eq 0
    end
  end

  context 'when service is up' do
    it 'yields and does not reschedule job' do
      allow_any_instance_of(DownTimeChecker).to receive(:down?).and_return(false)
      middleware = described_class.new
      count = 0
      worker = class_double('Worker')
      expect(worker).to receive(:downtime_checks).and_return([{ service_name: 'BDN', extra_delay: 0 }])
      expect(worker).not_to receive(:perform_in)

      middleware.call(worker, nil, nil) do
        count += 1
      end
      expect(count).to eq 1
    end
  end
end
