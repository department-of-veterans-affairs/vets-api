# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CovidVaccine::ExpandedEligibilityJob, type: :worker do
  subject { described_class.new }

  let(:registration_submission) do
    create(:covid_vax_expanded_registration)
  end

  let(:mvi_profile) { build(:mvi_profile) }
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

  describe '#perform' do
    context 'for non-veteran applicant' do
      let(:registration_submission) { create(:covid_vax_expanded_registration, :spouse) }

      it 'raises if no submission exists' do
        expect { subject.perform('non-existent-submission-id') }.to raise_error(StandardError)
      end

      it 'populates eligibility info' do
        subject.perform(registration_submission.id)
        registration_submission.reload
        expect(registration_submission.eligibility_info).to be_truthy
      end

      it 'marks applicant as eligible' do
        subject.perform(registration_submission.id)
        registration_submission.reload
        expect(registration_submission.eligibility_info['eligible']).to be_truthy
      end

      it 'updates state machine' do
        subject.perform(registration_submission.id)
        registration_submission.reload
        expect(registration_submission).to be_eligible
      end
    end

    context 'for a veteran applicant' do
      it 'adds ICN from MPI if available' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        subject.perform(registration_submission.id)
        registration_submission.reload
        expect(registration_submission.eligibility_info['icn']).to eq(mvi_profile.icn)
        expect(registration_submission.eligibility_info['mpi_query_timestamp']).to be_truthy
      end

      it 'omits ICN if user not found' do
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_not_found)
        subject.perform(registration_submission.id)
        registration_submission.reload
        expect(registration_submission.eligibility_info['icn']).to be_nil
        expect(registration_submission.eligibility_info['mpi_query_timestamp']).to be_truthy
      end

      describe 'self-reported eligibility checks' do
        before do
          expect_any_instance_of(MPI::Service).to receive(:find_profile).and_return(mvi_profile_response)
        end

        it 'considers 1 month of service ineligible' do
          submission = create(:covid_vax_expanded_registration,
                              raw_options: { 'date_range' => { 'from' => '2001-01-XX', 'to' => '2001-01-XX' } })
          subject.perform(submission.id)
          submission.reload
          expect(submission).to be_ineligible
          expect(submission.eligibility_info['ineligible_reason']).to eq('self_reported_period_of_service')
        end

        it 'considers 23 months of service ineligible' do
          submission = create(:covid_vax_expanded_registration,
                              raw_options: { 'date_range' => { 'from' => '2001-01-XX', 'to' => '2002-11-XX' } })
          subject.perform(submission.id)
          submission.reload
          expect(submission).to be_ineligible
          expect(submission.eligibility_info['ineligible_reason']).to eq('self_reported_period_of_service')
        end

        it 'considers 24 months of service eligible' do
          submission = create(:covid_vax_expanded_registration,
                              raw_options: { 'date_range' => { 'from' => '2001-01-XX', 'to' => '2002-12-XX' } })
          subject.perform(submission.id)
          submission.reload
          expect(submission).to be_eligible
        end

        it 'considers 30 months of service eligible' do
          submission = create(:covid_vax_expanded_registration,
                              raw_options: { 'date_range' => { 'from' => '2001-01-XX', 'to' => '2003-06-XX' } })
          subject.perform(submission.id)
          submission.reload
          expect(submission).to be_eligible
        end

        ['Dishonorable', 'Bad Conduct'].each do |status|
          it "considers #{status} ineligible" do
            submission = create(:covid_vax_expanded_registration, raw_options: { 'character_of_service' => status })
            subject.perform(submission.id)
            submission.reload
            expect(submission).to be_ineligible
            expect(submission.eligibility_info['ineligible_reason']).to eq('self_reported_character_of_service')
          end
        end

        ['Honorable', 'General', 'Other Than Honorable', 'Undesirable'].each do |status|
          it "considers #{status} eligible" do
            submission = create(:covid_vax_expanded_registration, raw_options: { 'character_of_service' => status })
            subject.perform(submission.id)
            submission.reload
            expect(submission).to be_eligible
          end
        end
      end
    end
  end
end
