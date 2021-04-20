# frozen_string_literal: true

require 'rails_helper'
require 'fugit'

RSpec.describe CovidVaccine::ExpandedScheduledSubmissionJob, type: :worker do
  describe 'schedule' do
    sidekiq_file = Rails.root.join('config', 'sidekiq_scheduler.yml')
    schedule = YAML.load_file(sidekiq_file)['CovidVaccine::ExpandedScheduledSubmissionJob']
    let(:parsed_schedule) { Fugit.do_parse(schedule['cron']) }

    let(:submission) { create(:covid_vax_expanded_registration, :unsubmitted) }

    it 'has a job class' do
      expect { schedule['class'].constantize }.not_to raise_error
    end

    it 'is scheduled in the eastern time zone' do
      expect(parsed_schedule.zone).to eq('America/New_York')
    end

    it 'is scheduled to run every 15 min' do
      expect(parsed_schedule.minutes).to eq([0, 15, 30, 45])
    end
  end

  describe '#perform' do
    context 'when records exist with state=enrollment_pending' do
      # before do 
      #   create(:covid_vax_expanded_registration).raw_form_data.symbolize_keys
      # end

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
  end
end
