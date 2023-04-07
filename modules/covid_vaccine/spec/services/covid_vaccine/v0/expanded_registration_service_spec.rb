# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::ExpandedRegistrationService do
  subject { described_class.new }

  let(:submission) { create(:covid_vax_expanded_registration, :unsubmitted) }
  let(:submission_no_facility) { create(:covid_vax_expanded_registration, :unsubmitted, :no_preferred_facility) }
  let(:submission_no_email) { create(:covid_vax_expanded_registration, :unsubmitted, :blank_email) }
  let(:submission_spouse) { create(:covid_vax_expanded_registration, :unsubmitted, :spouse) }
  let(:submission_non_us) { create(:covid_vax_expanded_registration, :unsubmitted, :non_us) }
  let(:submission_composite_facility) { create(:covid_vax_expanded_registration, :unsubmitted, :composite_facility) }
  let(:submission_eligibility_info) { create(:covid_vax_expanded_registration, :unsubmitted, :eligibility_info) }
  let(:submission_enrollment_complete) do
    create(:covid_vax_expanded_registration, :unsubmitted, :state_enrollment_complete)
  end

  let(:profile) { build(:mpi_profile, { vha_facility_ids: %w[358 516 553 200HD 200IP 200MHV] }) }
  let(:mpi_profile_no_facility) { build(:mpi_profile) }

  let(:mpi_profile_response) { create(:find_profile_response, profile:) }
  let(:mpi_profile_not_found) { create(:find_profile_not_found_response) }
  let(:mpi_facility_not_found) { create(:find_profile_response, profile: mpi_profile_no_facility) }

  vcr_options = { cassette_name: 'covid_vaccine/registration_facilities',
                  match_requests_on: %i[path query],
                  record: :new_episodes }

  describe '#register', vcr: vcr_options do
    context 'unauthenticated' do
      it 'coerces input to vetext format' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(:first_name,
                               :last_name,
                               :patient_ssn,
                               :date_of_birth,
                               :patient_icn,
                               :phone,
                               :email,
                               :address,
                               :city,
                               :state,
                               :zip_code,
                               :authenticated,
                               :applicant_type,
                               :sms_acknowledgement,
                               :privacy_agreement_accepted,
                               :enhanced_eligibility,
                               :birth_sex,
                               :last_branch_of_service,
                               :character_of_service,
                               :service_date_range,
                               :sta3n,
                               :sta6a,
                               :vaccine_interest))
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)

        subject.register(submission)
        expect(submission.reload.vetext_sid).to match(sid)
        expect(submission.reload.vetext_sid).to be_truthy
      end

      it 'passes authenticated attribute as false' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(authenticated: false))
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission)
        expect(submission.reload.vetext_sid).to match(sid)
        expect(submission.reload.vetext_sid).to be_truthy
      end

      it 'updates submission record' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission)
        expect(submission.reload.vetext_sid).to match(sid)
        expect(submission.reload.vetext_sid).to be_truthy
      end

      it 'updates state to registered' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission)
        expect(submission.reload.vetext_sid).to match(sid)
        expect(submission.reload.state).to match('registered')
      end

      it 'adds ICN to Nil enrollment data' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission)
        expect(submission.reload.vetext_sid).to match(sid)
        expect(submission.reload.eligibility_info_ciphertext).not_to be_nil
      end

      it 'adds ICN to non Nil encrypted enrollment data' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission_eligibility_info)
        expect(submission_eligibility_info.reload.vetext_sid).to match(sid)
        expect(submission_eligibility_info.reload.eligibility_info_ciphertext).not_to be_nil
      end

      it 'allows a spouse to register' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission_spouse)
        expect(submission_spouse.reload.vetext_sid).to match(sid)
        expect(submission_spouse.reload.state).to match('registered')
      end

      it 'allows non us address and facility' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission_non_us)
        expect(submission_non_us.reload.vetext_sid).to match(sid)
        expect(submission_non_us.reload.state).to match('registered')
      end

      it 'submits when email does not exist' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission_no_email)
        expect(submission_no_email.reload.vetext_sid).to match(sid)
        expect(submission_no_email.reload.state).to match('registered')
      end

      it 'submits with a composite facility ID' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        subject.register(submission_composite_facility)
        expect(submission_composite_facility.reload.vetext_sid).to match(sid)
        expect(submission_composite_facility.reload.state).to match('registered')
      end

      context 'without sufficient traits' do
        it 'does not register when lacking traits for MVI lookup' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
            .and_return(mpi_profile_not_found)
          expect(Rails.logger).to receive(:info).with(
            'CovidVaccine::V0::ExpandedRegistrationService:Error in MPI Lookup',
            'mpi_error': 'no ICN found', 'submission': submission.id,
            'submission_date': submission.created_at
          )
          subject.register(submission)
        end

        it 'does not send data when facility does not match' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
            .and_return(mpi_facility_not_found)
          expect(Rails.logger).to receive(:info).with(
            'CovidVaccine::V0::ExpandedRegistrationService:Error in MPI Lookup',
            'mpi_error': 'no matching facility found for 516',
            'submission': submission.id, 'submission_date': submission.created_at
          )
          subject.register(submission)
        end

        it 'does not submit when preferred location does not exist and MPI matches ICN' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
            .and_return(mpi_facility_not_found)
          expect(Rails.logger).to receive(:info).with("#{described_class}:Error in MPI Lookup",
                                                      'mpi_error': 'no matching facility found for ',
                                                      'submission': submission_no_facility.id,
                                                      'submission_date': submission_no_facility.created_at)
          expect(Rails.logger).to receive(:info).with("#{described_class}:No preferred facility selected",
                                                      'submission': submission_no_facility.id,
                                                      'submission_date': submission_no_facility.created_at)
          subject.register(submission_no_facility)
          expect(submission_no_facility.reload.vetext_sid).to be_nil
          expect(submission_no_facility.reload.state).to match('enrollment_pending')
        end

        it 'does not submit when preferred location does not exist and MPI does not match ICN' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
            .and_return(mpi_profile_not_found)
          expect(Rails.logger).to receive(:info).with("#{described_class}:Error in MPI Lookup",
                                                      'mpi_error': 'no ICN found',
                                                      'submission': submission_no_facility.id,
                                                      'submission_date': submission_no_facility.created_at)
          expect(Rails.logger).to receive(:info).with("#{described_class}:No preferred facility selected",
                                                      'submission': submission_no_facility.id,
                                                      'submission_date': submission_no_facility.created_at)
          subject.register(submission_no_facility)
          expect(submission_no_facility.reload.vetext_sid).to be_nil
          expect(submission_no_facility.reload.state).to match('enrollment_pending')
        end

        context 'with state=enrollment_complete' do
          it 'updates submission record' do
            sid = SecureRandom.uuid
            allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
              .and_return({ sid: })
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_profile_response)
            subject.register(submission_enrollment_complete)
            expect(submission_enrollment_complete.reload.vetext_sid).to match(sid)
            expect(submission_enrollment_complete.reload.vetext_sid).to be_truthy
          end

          it 'updates state to registered' do
            sid = SecureRandom.uuid
            allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
              .and_return({ sid: })
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_profile_response)
            subject.register(submission_enrollment_complete)
            expect(submission_enrollment_complete.reload.vetext_sid).to match(sid)
            expect(submission_enrollment_complete.reload.state).to match('registered')
          end
        end

        context 'with created_at older than 24 hours' do
          before do
            submission.created_at = 1.day.ago
            submission.save!
            submission_no_facility.created_at = 1.day.ago
            submission_no_facility.save!
            submission_enrollment_complete.created_at = 1.day.ago
            submission_enrollment_complete.save!
          end

          it 'submits and updates state when MPI Profile is not found' do
            sid = SecureRandom.uuid
            allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
              .and_return({ sid: })
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_profile_not_found)

            subject.register(submission)
            expect(submission.reload.vetext_sid).to match(sid)
            expect(submission.reload.state).to match('registered_no_icn')
          end

          it 'submits and updates state when MPI facility does not match' do
            sid = SecureRandom.uuid
            allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
              .and_return({ sid: })
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_facility_not_found)

            subject.register(submission)
            expect(submission.reload.vetext_sid).to match(sid)
            expect(submission.reload.state).to match('registered_no_facility')
          end

          it 'submits and updates state when preferred location does not exist and MPI matches ICN' do
            sid = SecureRandom.uuid
            allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
              .and_return({ sid: })
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_facility_not_found)

            subject.register(submission_no_facility)
            expect(submission_no_facility.reload.vetext_sid).to match(sid)
            expect(submission_no_facility.reload.state).to match('registered_no_facility')
          end

          it 'submits and updates state when preferred location does not exist and MPI does not match ICN' do
            sid = SecureRandom.uuid
            allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
              .and_return({ sid: })
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_profile_not_found)

            subject.register(submission_no_facility)
            expect(submission_no_facility.reload.vetext_sid).to match(sid)
            expect(submission_no_facility.reload.state).to match('registered_no_icn')
          end

          context 'with state=enrollment_complete' do
            it 'updates submission record' do
              sid = SecureRandom.uuid
              allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
                .and_return({ sid: })
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
                .and_return(mpi_profile_response)
              subject.register(submission_enrollment_complete)
              expect(submission_enrollment_complete.reload.vetext_sid).to match(sid)
              expect(submission_enrollment_complete.reload.vetext_sid).to be_truthy
            end

            it 'updates state to registered' do
              sid = SecureRandom.uuid
              allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
                .and_return({ sid: })
              allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
                .and_return(mpi_profile_response)
              subject.register(submission_enrollment_complete)
              expect(submission_enrollment_complete.reload.vetext_sid).to match(sid)
              expect(submission_enrollment_complete.reload.state).to match('registered')
            end
          end
        end

        context 'with created_at newer than 24 hours' do
          created_at_date = 23.hours.ago
          before do
            submission.created_at = created_at_date
            submission.save!
            submission_no_facility.created_at = created_at_date
            submission_no_facility.save!
          end

          it 'does not submit when MPI Facility does not match' do
            expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_facility_not_found)
            subject.register(submission)
            expect(submission.reload.vetext_sid).to be_nil
            expect(submission.reload.state).to match('enrollment_pending')
          end

          it 'does not submit when MPI Profile is not found' do
            expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_profile_not_found)
            subject.register(submission)
            expect(submission.reload.vetext_sid).to be_nil
            expect(submission.reload.state).to match('enrollment_pending')
          end

          it 'does not submit when No facility is selected' do
            expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
            allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
              .and_return(mpi_facility_not_found)
            subject.register(submission_no_facility)
            expect(submission_no_facility.reload.vetext_sid).to be_nil
            expect(submission_no_facility.reload.state).to match('enrollment_pending')
          end
        end
      end
    end
  end
end
