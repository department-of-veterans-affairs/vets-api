# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::ExpandedSubmissionJob, type: :worker do
  subject { described_class.new }

  describe '#perform expanded submission job' do
    let(:expected_attributes) do
      %w[first_name last_name phone email_address birth_date ssn preferred_facility city
         state_code zip_code applicant_type privacy_agreement_accepted birth_sex]
    end
    let(:submission) { create(:covid_vax_expanded_registration, :unsubmitted) }
    let(:profile) { build(:mpi_profile, { vha_facility_ids: %w[358 516 553 200HD 200IP 200MHV] }) }
    let(:mpi_profile_no_facility) { build(:mpi_profile) }
    let(:mpi_profile_response) { create(:find_profile_response, profile:) }
    let(:mpi_profile_not_found) { create(:find_profile_not_found_response) }

    it 'updates the submission object' do
      sid = SecureRandom.uuid
      allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
        .and_return({ sid: })
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
        .and_return(mpi_profile_response)
      subject.perform(submission.id)
      submission.reload
      expect(submission.vetext_sid).to be_truthy
      expect(submission.raw_form_data).to be_truthy
      expect(submission.raw_form_data).to include(*expected_attributes)
    end

    context 'without sufficient traits' do
      it 'does not update state when MVI lookup error' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_not_found)
        subject.perform(submission.id)
        expect(submission.reload.state).to match('enrollment_pending')
      end
    end

    it 'raises an error if submission is missing' do
      with_settings(Settings.sentry, dsn: 'T') do
        expect(Raven).to receive(:capture_exception)
        expect { subject.perform('fakeid') }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
