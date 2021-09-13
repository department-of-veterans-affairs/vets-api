# frozen_string_literal: true

require 'rails_helper'
require 'middleware/sidekiq/only_run_while_up'

describe Middleware::Sidekiq::OnlyRunWhileUp do
  context 'when service is down' do
    it 'does not yield, but reschedules job' do
      delay = 6.hours
      allow_any_instance_of(DownTimeChecker).to receive(:down?) { delay }
      middleware = described_class.new
      count = 0
      worker = BGS::SubmitForm686cJob.new
      job = double('job')
      allow(job).to receive(:[]).with('args').and_return({ one: 1 })
      expect(worker).to receive(:downtime_checks).and_return([{ service_name: 'BDN', extra_delay: 0 }])
      expect(worker.class).to receive(:perform_in).with(delay, { one: 1 })

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
