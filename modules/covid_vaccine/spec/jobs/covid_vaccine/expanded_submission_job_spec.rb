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

    let(:mvi_profile) { build(:mvi_profile, { vha_facility_ids: %w[358 516 553 200HD 200IP 200MHV] }) }
    let(:mvi_profile_no_facility) { build(:mvi_profile) }

    let(:mvi_profile_response) do
      MPI::Responses::FindProfileResponse.new(
        status: MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
        profile: mvi_profile
      )
    end
    let(:mvi_profile_not_found) do
      MPI::Responses::FindProfileResponse.new(
        status: MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:not_found],
        profile: nil
      )
    end
    let(:mvi_facility_not_found) do
      MPI::Responses::FindProfileResponse.new(
        status: MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
        profile: mvi_profile_no_facility
      )
    end

    it 'updates the submission object' do
      sid = SecureRandom.uuid
      allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
        .and_return({ sid: sid })
      allow_any_instance_of(MPI::Service).to receive(:find_profile)
        .and_return(mvi_profile_response)
      subject.perform(submission.id)
      submission.reload
      expect(submission.vetext_sid).to be_truthy
      expect(submission.raw_form_data).to be_truthy
      expect(submission.raw_form_data).to include(*expected_attributes)
    end

    context 'without sufficient traits' do
      it 'raises exception for MVI lookup error' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_not_found)
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with('Record not found.')
        subject.perform(submission.id)
      end

      it 'does not update state when MVI lookup error' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_not_found)
        subject.perform(submission.id)
        expect(submission.reload.state).to match('enrollment_pending')
      end

      it 'raises exception for MVI facility discrepancy error' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_facility_not_found)
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with('Record not found.')
        subject.perform(submission.id)
        expect(submission.reload.state).to match('enrollment_pending')
      end

      it 'does not update state when MVI facility discrepancy error' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_facility_not_found)
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
