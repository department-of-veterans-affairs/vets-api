# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::ExpandedRegistrationService do
  subject { described_class.new }

  let(:form_data) do
    { 'vaccine_interest' => 'INTERESTED', 'phone' => '650-555-1212',
      'email' => 'foo@bar.com', 'first_name' => 'Sean',
      'last_name' => 'Gptestkfive', 'birth_date' => '1972-03-21',
      'ssn' => '666512797', 'zip_code' => '97412', 'preferred_facility' => 'vha_648', 
      'address_line1' => '123 test st', 'address_line2' => 'Madigan Barracks', 
      'address_line3' => 'Apt 3', 'city' => 'Portland', 'state_code' => 'OR', 
      'sms_acknowledgement' => 'true', 'birth_sex' => 'male', 
      'applicant_type' => 'CHAMPVA', 'privacy_agreement_accepted' => 'true'}
  end
  let(:sparse_form_data) do
    { 'vaccine_interest' => 'INTERESTED', 'phone' => '650-555-1212',
    'first_name' => 'Sean', 'last_name' => 'Gptestkfive', 
    'birth_date' => '1972-03-21', 'ssn' => '666512797', 'zip_code' => '97412', 
    'preferred_facility' => 'vha_648', 'address_line1' => '123 test st',  
    'city' => 'Portland', 'state_code' => 'OR', 'sms_acknowledgement' => 'true', 
    'birth_sex' => 'male', 'applicant_type' => 'CHAMPVA', 'privacy_agreement_accepted' => 'true'}
  end
  let(:submission) { build(:covid_vax_registration, :unsubmitted) }
  let(:insufficient_submission) do
    build(:covid_vax_registration,
          :unsubmitted,
          :lacking_pii_traits)
  end
  let(:loa3_submission) { build(:covid_vax_registration, :unsubmitted, :from_loa3) }

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

  vcr_options = { cassette_name: 'covid_vaccine/registration_facilities',
                  match_requests_on: %i[path query],
                  record: :new_episodes }

  describe '#register', vcr: vcr_options do
    context 'unauthenticated' do
      it 'coerces input to vetext format' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(:first_name,
                               :last_name,
                               :patient_ssn,
                               :date_of_birth,
                               :patient_icn,
                               :phone,
                               :email,
                               :zip_code,
                               :time_at_zip,
                               :zip_lat,
                               :zip_lon,
                               :sta3n,
                               :authenticated))
          .and_return({ sid: SecureRandom.uuid })
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)

        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
      end

      it 'passes authenticated attribute as false' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(authenticated: false))
          .and_return({ sid: SecureRandom.uuid })
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
      end

      it 'updates submission record' do
        sid = SecureRandom.uuid
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)

        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        expect(submission.reload.sid).to be_truthy
      end

      context 'with sufficient traits' do
        it 'injects user traits from MPI when found' do
          expect_any_instance_of(MPI::Service).to receive(:find_profile)
            .and_return(mvi_profile_response)
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .with(hash_including(first_name: mvi_profile.given_names&.first))
            .and_return({ sid: SecureRandom.uuid })
          expect { subject.register(submission, 'unauthenticated') }
            .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        end

        it 'proceeds without traits from MPI when not found' do
          expect_any_instance_of(MPI::Service).to receive(:find_profile)
            .and_return(mvi_profile_not_found)
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .with(hash_including(first_name: submission.raw_form_data['first_name']))
            .and_return({ sid: SecureRandom.uuid })
          expect { subject.register(submission, 'unauthenticated') }
            .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        end
      end

      context 'with insufficient traits' do
        it 'omits MPI query' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .and_return({ sid: SecureRandom.uuid })
          expect_any_instance_of(MPI::Service).not_to receive(:find_profile)
          expect { subject.register(insufficient_submission, 'unauthenticated') }
            .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        end
      end

      context 'with an unparseable date attribute' do
        let(:bad_date_submission) do
          build(:covid_vax_registration,
                :unsubmitted,
                :invalid_dob)
        end

        it 'omits MPI query' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .and_return({ sid: SecureRandom.uuid })
          expect_any_instance_of(MPI::Service).not_to receive(:find_profile)
          expect { subject.register(bad_date_submission, 'unauthenticated') }
            .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        end
      end
    end


  end
end
