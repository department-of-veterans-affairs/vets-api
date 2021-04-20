# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::ExpandedSubmissionStateJob, type: :worker do
  subject { described_class.new }

  describe 'schedule' do
    sidekiq_file = Rails.root.join('config', 'sidekiq_scheduler.yml')
    schedule = YAML.load_file(sidekiq_file)['CovidVaccine::ExpandedSubmissionStateJob']

    it 'has a job class' do
      expect { schedule['class'].constantize }.not_to raise_error
    end
  end

  describe '#perform expanded submission state job' do
    context 'all states exist in records' do
      before do
        create(:covid_vax_expanded_registration, :unsubmitted, :state_received)
        create(:covid_vax_expanded_registration, :unsubmitted, :state_enrollment_pending)
        create(:covid_vax_expanded_registration, :unsubmitted, :state_enrollment_complete)
        create(:covid_vax_expanded_registration, :unsubmitted, :state_registered)
        create(:covid_vax_expanded_registration, :unsubmitted, :state_enrollment_out_of_band)
      end

      it 'logs data for each submission type' do
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Expanded_Submission_State_Job Start')
        expect(Rails.logger).to receive(:info).with('CovidVaccine::ExpandedSubmissionStateJob: Count of states',
                                                    'enrollment_complete': 1, 'enrollment_out_of_band': 1,
                                                    'enrollment_pending': 1, 'registered': 1, 'received': 1)
        subject.perform
      end
    end

    context 'states do not exist in records' do
      before do
        create(:covid_vax_expanded_registration, :unsubmitted, :state_enrollment_pending)
        create(:covid_vax_expanded_registration, :unsubmitted, :state_enrollment_pending)
        create(:covid_vax_expanded_registration, :unsubmitted, :state_registered)
        create(:covid_vax_expanded_registration, :unsubmitted, :state_enrollment_out_of_band)
      end

      it 'logs data for each submission type' do
        expect(Rails.logger).to receive(:info).with('Covid_Vaccine Expanded_Submission_State_Job Start')
        expect(Rails.logger).to receive(:info).with('CovidVaccine::ExpandedSubmissionStateJob: Count of states',
                                                    'enrollment_out_of_band': 1, 'enrollment_pending': 2,
                                                    'registered': 1)
        subject.perform
      end
    end
  end
end
