# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::RegistrationService do
  subject { described_class.new }

  let(:form_data) do
    { 'vaccine_interest' => 'INTERESTED', 'phone' => '650-555-1212',
      'email' => 'foo@bar.com', 'first_name' => 'Sean',
      'last_name' => 'Gptestkfive', 'birth_date' => '1972-03-21',
      'ssn' => '666512797', 'zip_code' => '97412', 'zip_code_details' => 'Yes' }
  end
  let(:sparse_form_data) do
    { 'vaccine_interest' => 'NOT INTERESTED', 'phone' => '650-555-1212',
      'email' => 'foo@bar.com', 'first_name' => 'Sean',
      'last_name' => 'Gptestkfive', 'zip_code' => '97412', 'zip_code_details' => 'Yes' }
  end
  let(:submission) { build(:covid_vax_registration, :unsubmitted) }
  let(:insufficient_submission) do
    build(:covid_vax_registration,
          :unsubmitted,
          :lacking_pii_traits)
  end
  let(:loa3_submission) { build(:covid_vax_registration, :unsubmitted, :from_loa3) }

  let(:profile) { build(:mpi_profile) }
  let(:mpi_profile_response) { create(:find_profile_response, profile:) }
  let(:mpi_profile_not_found) { create(:find_profile_not_found_response) }

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
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)

        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
      end

      it 'passes authenticated attribute as false' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(authenticated: false))
          .and_return({ sid: SecureRandom.uuid })
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
      end

      it 'updates submission record' do
        sid = SecureRandom.uuid
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: })
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)

        expect { subject.register(submission, 'unauthenticated') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        expect(submission.reload.sid).to be_truthy
      end

      context 'with sufficient traits' do
        it 'injects user traits from MPI when found' do
          expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
            .and_return(mpi_profile_response)
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .with(hash_including(first_name: profile.given_names&.first))
            .and_return({ sid: SecureRandom.uuid })
          expect { subject.register(submission, 'unauthenticated') }
            .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        end

        it 'proceeds without traits from MPI when not found' do
          expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
            .and_return(mpi_profile_not_found)
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
          expect_any_instance_of(MPI::Service).not_to receive(:find_profile_by_attributes)
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
          expect_any_instance_of(MPI::Service).not_to receive(:find_profile_by_attributes)
          expect { subject.register(bad_date_submission, 'unauthenticated') }
            .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        end
      end
    end

    context 'authenticated LOA3' do
      let(:user) { build(:user, :mhv) }

      it 'uses traits from proofed user' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(first_name: loa3_submission.raw_form_data['first_name']))
          .and_return({ sid: SecureRandom.uuid })
        expect { subject.register(loa3_submission, 'loa3') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
      end

      it 'omits MPI query' do
        expect_any_instance_of(MPI::Service).not_to receive(:find_profile_by_attributes)
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: SecureRandom.uuid })
        expect { subject.register(loa3_submission, 'loa3') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
      end

      it 'passes authenticated attribute as true' do
        expect_any_instance_of(MPI::Service).not_to receive(:find_profile_by_attributes)
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(authenticated: true))
          .and_return({ sid: SecureRandom.uuid })
        expect { subject.register(loa3_submission, 'loa3') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
      end
    end

    context 'authenticated LOA1' do
      let(:user) { build(:user, :mhv, :loa1) }

      context 'with sufficient traits' do
        it 'injects user traits from MPI when found' do
          expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
            .and_return(mpi_profile_response)
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .with(hash_including(first_name: profile.given_names&.first))
            .and_return({ sid: SecureRandom.uuid })
          expect { subject.register(submission, 'loa1') }
            .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
        end
      end

      it 'passes authenticated attribute as false' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(authenticated: false))
          .and_return({ sid: SecureRandom.uuid })
        expect_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes)
          .and_return(mpi_profile_response)
        expect { subject.register(submission, 'loa1') }
          .to change(CovidVaccine::RegistrationEmailJob.jobs, :size).by(1)
      end
    end
  end
end
