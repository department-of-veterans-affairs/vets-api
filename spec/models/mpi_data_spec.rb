# frozen_string_literal: true

require 'rails_helper'

describe MPIData, :skip_mvi do
  let(:user) { build(:user, :loa3, :no_mpi_profile) }

  describe '.for_user' do
    subject { MPIData.for_user(user.identity) }

    it 'creates an instance with given user identity attributes' do
      mpi_data = subject
      expect(mpi_data.user_loa3).to eq(user.identity.loa3?)
      expect(mpi_data.user_icn).to eq(user.identity.icn)
      expect(mpi_data.user_first_name).to eq(user.identity.first_name)
      expect(mpi_data.user_last_name).to eq(user.identity.last_name)
      expect(mpi_data.user_birth_date).to eq(user.identity.birth_date)
      expect(mpi_data.user_ssn).to eq(user.identity.ssn)
      expect(mpi_data.user_edipi).to eq(user.identity.edipi)
      expect(mpi_data.user_logingov_uuid).to eq(user.identity.logingov_uuid)
      expect(mpi_data.user_idme_uuid).to eq(user.identity.idme_uuid)
      expect(mpi_data.user_uuid).to eq(user.identity.uuid)
    end
  end

  describe '#add_person_proxy' do
    subject { mpi_data.add_person_proxy(as_agent:) }

    let(:as_agent) { false }
    let(:mpi_data) { MPIData.for_user(user.identity) }
    let(:profile_response_error) { create(:find_profile_server_error_response) }
    let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }
    let(:mpi_profile) { build(:mpi_profile) }

    context 'with a successful add' do
      let(:add_response) { create(:add_person_response, parsed_codes:) }
      let(:parsed_codes) do
        {
          birls_id:,
          participant_id:
        }
      end
      let(:birls_id) { '111985523' }
      let(:participant_id) { '32397028' }
      let(:given_names) { %w[kitty] }
      let(:family_name) { 'banana' }
      let(:suffix) { 'Jr' }
      let(:birth_date) { '19801010' }
      let(:address) do
        {
          street: '1600 Pennsylvania Ave',
          city: 'Washington',
          state: 'DC',
          country: 'USA',
          postal_code: '20500'
        }
      end
      let(:icn) { 'some-icn' }
      let(:edipi) { 'some-edipi' }
      let(:search_token) { 'some-search_token' }
      let(:gender) { 'M' }
      let(:ssn) { '987654321' }
      let(:phone) { '(800) 867-5309' }
      let(:person_types) { ['VET'] }
      let(:mpi_profile) do
        build(:mpi_profile,
              given_names:,
              family_name:,
              birth_date:,
              icn:,
              edipi:,
              search_token:,
              ssn:,
              person_types:,
              gender:)
      end

      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes_with_orch_search)
          .and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:add_person_proxy).and_return(add_response)
      end

      it 'creates a birls_id from add_person_proxy and adds it to existing mpi data object' do
        expect { subject }.to change(mpi_data, :birls_id).from(user.birls_id).to(birls_id)
      end

      it 'creates a participant_id from add_person_proxy and adds it to existing mpi data object' do
        expect { subject }.to change(mpi_data, :participant_id).from(user.participant_id).to(participant_id)
      end

      it 'copies relevant results from orchestration search to fields for add person call' do
        subject

        expect(mpi_data.birls_id).to eq(birls_id)
        expect(mpi_data.participant_id).to eq(participant_id)
      end

      it 'clears the cached MPI response' do
        mpi_data.status
        expect(mpi_data).to be_mpi_response_is_cached
        subject
        expect(mpi_data).not_to be_mpi_response_is_cached
      end

      it 'returns the successful response' do
        expect(subject.ok?).to be(true)
      end

      context 'with as_agent set to true' do
        let(:as_agent) { true }

        it 'returns the successful response' do
          expect(subject.ok?).to be(true)
        end

        it 'calls add_person_proxy with as_agent set to true' do
          expect_any_instance_of(MPI::Service).to receive(:add_person_proxy).with(
            last_name: family_name,
            ssn:,
            birth_date:,
            icn:,
            edipi:,
            search_token:,
            first_name: given_names.first,
            as_agent:
          )
          subject
        end
      end
    end

    context 'with a failed search' do
      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes_with_orch_search)
          .and_return(profile_response_error)
      end

      it 'returns the response from the failed search' do
        expect_any_instance_of(MPI::Service).not_to receive(:add_person_proxy)
        expect(subject).to eq(profile_response_error)
      end
    end

    context 'with a failed add' do
      let(:add_response_error) { create(:add_person_server_error_response) }

      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_attributes_with_orch_search)
          .and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:add_person_proxy).and_return(add_response_error)
      end

      it 'returns the failed add response' do
        expect_any_instance_of(MPIData).not_to receive(:add_ids)
        expect_any_instance_of(MPIData).not_to receive(:cache)
        response = subject
        expect(response.server_error?).to be(true)
      end
    end
  end

  describe '#profile' do
    subject { mpi_data.profile }

    let(:mpi_data) { MPIData.for_user(user.identity) }

    context 'when user is not loa3' do
      let(:user) { build(:user) }

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end

    context 'when user is loa3' do
      let(:profile_response) { 'some-profile-response' }

      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
      end

      context 'and there is cached data for a successful response' do
        let(:mpi_profile) { build(:mpi_profile_response) }
        let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before { mpi_data.cache(user.uuid, profile_response) }

        it 'returns the cached data' do
          expect(MPIData.find(user.uuid).response).to have_deep_attributes(profile_response)
        end
      end

      context 'and there is cached data for a server error response' do
        let(:profile_response) { create(:find_profile_server_error_response) }

        before { mpi_data.cache(user.uuid, profile_response) }

        it 'returns the cached data' do
          expect(MPIData.find(user.uuid).response).to have_deep_attributes(profile_response)
        end
      end

      context 'and there is cached data for a not found response' do
        let(:profile_response) { create(:find_profile_not_found_response) }

        before { mpi_data.cache(user.uuid, profile_response) }

        it 'returns the cached data' do
          expect(MPIData.find(user.uuid).response).to have_deep_attributes(profile_response)
        end
      end

      context 'and there is not cached data for a response' do
        context 'and the response is successful' do
          let(:mpi_profile) { build(:mpi_profile_response) }
          let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

          it 'returns the successful response' do
            expect(subject).to eq(mpi_profile)
          end

          it 'caches the successful response' do
            subject
            expect(MPIData.find(user.icn).response).to have_deep_attributes(profile_response)
          end
        end

        context 'and the response is not successful with not found response' do
          let(:profile_response) { create(:find_profile_not_found_response, profile:) }
          let(:profile) { 'some-unsuccessful-profile' }

          it 'returns the unsuccessful response' do
            expect(subject).to eq(profile)
          end

          it 'caches the unsuccessful response' do
            subject
            expect(MPIData.find(user.icn).response.profile).to eq(profile)
          end
        end

        context 'and the response is not successful with server error response' do
          let(:profile_response) { create(:find_profile_server_error_response, profile:) }
          let(:profile) { 'some-unsuccessful-profile' }

          it 'returns the unsuccessful response' do
            expect(subject).to eq(profile)
          end

          it 'does not cache the unsuccessful response' do
            subject
            expect(MPIData.find(user.icn)).to be_nil
          end
        end
      end
    end
  end

  describe 'delegated attribute functions' do
    context 'with a successful response' do
      let(:mpi_data) { MPIData.for_user(user.identity) }
      let(:mpi_profile) { build(:mpi_profile) }
      let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
      end

      describe '#edipi' do
        it 'matches the response' do
          expect(mpi_data.edipi).to eq(profile_response.profile.edipi)
        end
      end

      describe '#edipis' do
        it 'matches the response' do
          expect(mpi_data.edipis).to eq(profile_response.profile.edipis)
        end
      end

      describe '#icn' do
        it 'matches the response' do
          expect(mpi_data.icn).to eq(profile_response.profile.icn)
        end
      end

      describe '#icn_with_aaid' do
        it 'matches the response' do
          expect(mpi_data.icn_with_aaid).to eq(profile_response.profile.icn_with_aaid)
        end
      end

      describe '#mhv_correlation_id' do
        it 'matches the response' do
          expect(mpi_data.mhv_correlation_id).to eq(profile_response.profile.mhv_correlation_id)
        end
      end

      describe '#participant_id' do
        it 'matches the response' do
          expect(mpi_data.participant_id).to eq(profile_response.profile.participant_id)
        end
      end

      describe '#participant_ids' do
        it 'matches the response' do
          expect(mpi_data.participant_ids).to eq(profile_response.profile.participant_ids)
        end
      end

      describe '#birls_id' do
        it 'matches the response' do
          expect(mpi_data.birls_id).to eq(profile_response.profile.birls_id)
        end
      end

      describe '#birls_ids' do
        it 'matches the response' do
          expect(mpi_data.birls_ids).to eq(profile_response.profile.birls_ids)
        end
      end

      describe '#mhv_ien' do
        it 'matches the response' do
          expect(mpi_data.mhv_ien).to eq(profile_response.profile.mhv_ien)
        end
      end

      describe '#mhv_iens' do
        it 'matches the response' do
          expect(mpi_data.mhv_iens).to eq(profile_response.profile.mhv_iens)
        end
      end

      describe '#vet360_id' do
        it 'matches the response' do
          expect(mpi_data.vet360_id).to eq(profile_response.profile.vet360_id)
        end
      end
    end

    context 'with an error response' do
      let(:mpi_data) { MPIData.for_user(user.identity) }
      let(:profile_response_error) { create(:find_profile_server_error_response, error:) }
      let(:error) { 'some-error' }

      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response_error)
      end

      it 'captures the error in #error' do
        expect(mpi_data.error).to eq(error)
      end

      describe '#edipi' do
        it 'is nil' do
          expect(mpi_data.edipi).to be_nil
        end
      end

      describe '#icn' do
        it 'is nil' do
          expect(mpi_data.icn).to be_nil
        end
      end

      describe '#icn_with_aaid' do
        it 'is nil' do
          expect(mpi_data.icn_with_aaid).to be_nil
        end
      end

      describe '#mhv_correlation_id' do
        it 'is nil' do
          expect(mpi_data.mhv_correlation_id).to be_nil
        end
      end

      describe '#participant_id' do
        it 'is nil' do
          expect(mpi_data.participant_id).to be_nil
        end
      end
    end
  end
end
