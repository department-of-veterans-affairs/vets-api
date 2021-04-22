# frozen_string_literal: true

require 'rails_helper'
require 'fugit'

RSpec.describe CovidVaccine::ExpandedScheduledSubmissionJob, type: :worker do
  let(:submission) { create(:covid_vax_expanded_registration, :unsubmitted) }

  describe 'schedule' do
    sidekiq_file = Rails.root.join('config', 'sidekiq_scheduler.yml')
    schedule = YAML.load_file(sidekiq_file)['CovidVaccine::ExpandedScheduledSubmissionJob']
    let(:parsed_schedule) { Fugit.do_parse(schedule['every']) }

    it 'has a job class' do
      expect { schedule['class'].constantize }.not_to raise_error
    end
  end

  describe '#perform' do
    context 'when records exist with state=enrollment_pending' do
      it 'enqueues a CovidVaccine::ExpandedSubmissionJob job' do
        create(:covid_vax_expanded_registration).raw_form_data.symbolize_keys
        expect { subject.perform }.to change(CovidVaccine::ExpandedSubmissionJob.jobs, :size).by(1)
      end

      it 'logs its progress' do
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Expanded_Scheduled_Submission: Start')
        subject.perform
      end
    end

    context 'when no records exist with state=enrollment_pending' do
      it 'does not enqueue a CovidVaccine::ExpandedSubmissionJob job' do
        subject.perform
        expect(CovidVaccine::ExpandedSubmissionJob.jobs.size).to eq(0)
      end
    end

    context 'when error occurs' do 

      before do
        # based on breakpoints, ExpandedRegistrationService register method is not called
        # Maybe that has to do with ExpandedScheduledSubmissionJob invoking perform_async? 
        # 
        #allow_any_instance_of(CovidVaccine::V0::ExpandedRegistrationService).to receive(:register)
        # .and_raise(ActiveRecord::ActiveRecordError)

        submission
        # 
        allow_any_instance_of(CovidVaccine::ExpandedSubmissionJob).to receive(:perform)
          .and_raise(ActiveRecord::ActiveRecordError)
      end
      it 'logs an error when an error occurs' do 
        # pending('Trying to figure out how to make this work ')

        expect(Rails.logger).to receive(:error).with('Covid_Vaccine Expanded_Scheduled_Submission: Failed')
        subject.perform()

        # I copied this code from another class cause I was frustrated. 
        # with_settings(Settings.sentry, dsn: 'T') do
        #   pending('Trying to figure out how to make this work ')
        #   expect(Rails.logger).to receive(:error).with('Covid_Vaccine Expanded_Scheduled_Submission: Failed')

        #   expect(Raven).to receive(:capture_exception)
        #   expect { subject.perform() }.to raise_error(ActiveRecord::ActiveRecordError)
        # end
  
        
      end

      it 'does not enqueue a CovidVaccine::ExpandedSubmissionJob job' do 
        # pending('Trying to figure out how to make this work ')

        subject.perform
        expect(CovidVaccine::ExpandedSubmissionJob.jobs.size).to eq(0)
      end

    end
  end
end
