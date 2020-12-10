# frozen_string_literal: true

require 'rails_helper'

describe CovidVaccine::V0::RegistrationService do
  subject { described_class.new }

  let(:form_data) do
    { 'vaccine_interest' => 'YES', 'contact_preference' => 'true',
      'contact_method' => 'email', 'phone' => '650-555-1212',
      'email' => 'foo@bar.com', 'first_name' => 'Sean',
      'last_name' => 'Gptestkfive', 'birth_date' => '1972-03-21',
      'ssn' => '666512797', 'preferred_facility' => 'vha_648' }
  end
  let(:sparse_form_data) do
    { 'vaccine_interest' => 'YES', 'contact_preference' => 'true',
      'contact_method' => 'email', 'phone' => '650-555-1212',
      'email' => 'foo@bar.com', 'first_name' => 'Sean',
      'last_name' => 'Gptestkfive', 'preferred_facility' => 'vha_648' }
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

  describe '#register' do
    context 'unauthenticated' do
      it 'coerces input to vetext format' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(contact: 'true'))
          .and_return({ sid: SecureRandom.uuid })
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        subject.register(form_data)
      end

      it 'saves a submission record' do
        sid = SecureRandom.uuid
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: sid })
        expect_any_instance_of(MPI::Service).to receive(:find_profile)
          .and_return(mvi_profile_response)
        subject.register(form_data)
        expect(CovidVaccine::V0::RegistrationSubmission.find_by(sid: sid)).to be_truthy
      end

      context 'with sufficient traits' do
        it 'injects user traits from MPI when found' do
          expect_any_instance_of(MPI::Service).to receive(:find_profile)
            .and_return(mvi_profile_response)
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .with(hash_including(first_name: mvi_profile.given_names&.first))
            .and_return({ sid: SecureRandom.uuid })
          subject.register(form_data)
        end

        it 'proceeds without traits from MPI when not found' do
          expect_any_instance_of(MPI::Service).to receive(:find_profile)
            .and_return(mvi_profile_not_found)
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .with(hash_including(first_name: form_data['first_name']))
            .and_return({ sid: SecureRandom.uuid })
          subject.register(form_data)
        end
      end

      context 'with insufficient traits' do
        it 'omits MPI query' do
          expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
            .and_return({ sid: SecureRandom.uuid })
          expect_any_instance_of(MPI::Service).not_to receive(:find_profile)
          subject.register(sparse_form_data)
        end
      end
    end

    context 'authenticated LOA3' do
      let(:user) { build(:user, :mhv) }

      it 'uses traits from proofed user' do
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .with(hash_including(first_name: user.first_name))
          .and_return({ sid: SecureRandom.uuid })
        subject.register_loa3_user(form_data, user)
      end

      it 'omits MPI query' do
        expect_any_instance_of(MPI::Service).not_to receive(:find_profile)
        expect_any_instance_of(CovidVaccine::V0::VetextService).to receive(:put_vaccine_registry)
          .and_return({ sid: SecureRandom.uuid })
        subject.register_loa3_user(form_data, user)
      end
    end

    context 'authenticated LOA1' do
      let(:user) { build(:user, :mhv, :loa1) }
    end
  end
end
