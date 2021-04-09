# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::ExpandedRegistrationService do
  subject { described_class.new }

  let(:submission) { build(:covid_vax_expanded_registration, :unsubmitted) }
  let(:submission_no_facility) { build(:covid_vax_expanded_registration, :unsubmitted, :no_preferred_facility) }
  let(:submission_no_email) { build(:covid_vax_expanded_registration, :unsubmitted, :blank_email) }
  let(:submission_spouse) { build(:covid_vax_expanded_registration, :unsubmitted, :spouse) }
  let(:submission_non_us) { build(:covid_vax_expanded_registration, :unsubmitted, :non_us) }
  let(:submission_composite_facility) { build(:covid_vax_expanded_registration, :unsubmitted, :composite_facility) }
  let(:submission_eligibility_info) { build(:covid_vax_expanded_registration, :unsubmitted, :eligibility_info) }

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

  vcr_options = { cassette_name: 'covid_vaccine/registration_facilities',
                  match_requests_on: %i[path query],
                  record: :new_episodes }

  describe '#register', vcr: vcr_options do
    context 'unauthenticated' do
      it 'coerces input to vetext format' do
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
          .and_return({ sid: SecureRandom.uuid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)

        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
      end

      it 'passes authenticated attribute as false' do
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(authenticated: false))
          .and_return({ sid: SecureRandom.uuid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
      end

      it 'updates submission record' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)

        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
        expect(submission.reload.vetext_sid).to be_truthy
      end

      it 'updates state to registered' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
        expect(submission.reload.state).to match('registered')
      end

      it 'adds ICN to Nil encrypted enrollment data' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
        expect(submission.reload.encrypted_eligibility_info).not_to be_nil
      end

      it 'adds ICN to non Nil encrypted enrollment data' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission_eligibility_info, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
        expect(submission_eligibility_info.reload.encrypted_eligibility_info).not_to be_nil
      end

      it 'allows a spouse to register' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission_spouse, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
        expect(submission_spouse.reload.state).to match('registered')
      end

      it 'allows non us address and facility' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission_non_us, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
        expect(submission_non_us.reload.state).to match('registered')
      end

      it 'submits but does not update email job when email does not exist' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission_no_email, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(0)
        expect(submission_no_email.reload.state).to match('registered')
      end

      it 'submits with a composite facility ID' do
        sid = SecureRandom.uuid
        allow_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        allow_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission_composite_facility, 'unauthenticated') }
          .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(1)
        expect(submission_composite_facility.reload.state).to match('registered')
      end

      context 'without sufficient traits' do
        it 'does not update email job when lacking traits' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
          allow_any_instance_of(MPI::Service).to receive(:find_profile)
            .and_return(mvi_profile_not_found)
          expect { subject.register(submission, 'unauthenticated') }
            .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(0)
        end

        it 'does not update email job when facility does not match' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
          allow_any_instance_of(MPI::Service).to receive(:find_profile)
            .and_return(mvi_facility_not_found)
          expect { subject.register(submission, 'unauthenticated') }
            .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(0)
        end

        it 'does not update email job when preferred location does not exist' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).not_to receive(:put_vaccine_registry)
          expect_any_instance_of(MPI::Service).not_to receive(:find_profile)
          expect { subject.register(submission_no_facility, 'unauthenticated') }
            .to change(CovidVaccine::ExpandedRegistrationEmailJob.jobs, :size).by(0)
        end
      end
    end
  end
end
