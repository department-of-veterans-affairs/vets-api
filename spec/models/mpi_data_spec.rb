# frozen_string_literal: true

require 'rails_helper'

describe MPIData, skip_mvi: true do
  let(:user) do
    build(:user, :loa3, :no_vha_facilities,
          edipi: nil, sec_id: nil, icn: nil, cerner_id: nil,
          cerner_facility_ids: nil)
  end
  let(:mvi) { MPIData.for_user(user.identity) }
  let(:mvi_profile) { build(:mvi_profile) }
  let(:parsed_codes) do
    {
      birls_id: birls_id,
      participant_id: participant_id
    }
  end
  let(:birls_id) { '111985523' }
  let(:participant_id) { '32397028' }
  let(:profile_response) do
    MPI::Responses::FindProfileResponse.new(
      status: MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
      profile: mvi_profile
    )
  end
  let(:profile_response_error) { MPI::Responses::FindProfileResponse.with_server_error(server_error_exception) }
  let(:profile_response_not_found) { MPI::Responses::FindProfileResponse.with_not_found(not_found_exception) }
  let(:add_response) do
    MPI::Responses::AddPersonResponse.new(
      status: :ok,
      parsed_codes: parsed_codes
    )
  end
  let(:add_response_error) { MPI::Responses::AddPersonResponse.new(status: :server_error) }
  let(:default_ttl) { REDIS_CONFIG[MPIData::REDIS_CONFIG_KEY.to_s]['each_ttl'] }
  let(:failure_ttl) { REDIS_CONFIG[MPIData::REDIS_CONFIG_KEY.to_s]['failure_ttl'] }

  describe '.new' do
    it 'creates an instance with user attributes' do
      expect(mvi.user_identity).to eq(user.identity)
    end
  end

  describe '.historical_icn_for_user' do
    subject { MPIData.historical_icn_for_user(user.identity) }

    let(:mpi_profile) { build(:mpi_profile_response, :with_historical_icns) }

    before do
      stub_mpi_historical_icns(mpi_profile)
    end

    context 'when user is not loa3' do
      let(:user) { build(:user) }

      it 'returns nil' do
        expect(subject).to eq(nil)
      end
    end

    context 'when user is loa3' do
      it 'returns historical icns from an mpi call for that user' do
        expect(subject).to eq(mpi_profile.historical_icns)
      end
    end
  end

  describe '#mvi_get_person_historical_icns' do
    subject { MPIData.new(user.identity).mvi_get_person_historical_icns }

    let(:mpi_profile) { build(:mpi_profile_response, :with_historical_icns) }

    before do
      stub_mpi_historical_icns(mpi_profile)
    end

    it 'returns historical icn data from MPI call for given user' do
      expect(subject).to eq(mpi_profile.historical_icns)
    end
  end

  describe '#add_person_proxy' do
    subject { mpi_data.add_person_proxy }

    let(:mpi_data) { MPIData.for_user(user.identity) }

    context 'with a successful add' do
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
      let(:mvi_profile) do
        build(:mvi_profile,
              given_names: given_names,
              family_name: family_name,
              birth_date: birth_date,
              icn: icn,
              edipi: edipi,
              search_token: search_token,
              ssn: ssn,
              person_types: person_types,
              gender: gender)
      end

      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:add_person_proxy).and_return(add_response)
      end

      it 'creates a birls_id from add_person_proxy and adds it to existing mpi data object' do
        expect { subject }.to change(mpi_data, :birls_id).from(mvi_profile.birls_id).to(birls_id)
      end

      it 'creates a participant_id from add_person_proxy and adds it to existing mpi data object' do
        expect { subject }.to change(mpi_data, :participant_id).from(mvi_profile.participant_id).to(participant_id)
      end

      it 'copies relevant results from orchestration search to fields for add person call' do
        subject

        expect(mpi_data.birls_id).to eq(birls_id)
        expect(mpi_data.participant_id).to eq(participant_id)
      end

      it 'returns the successful response' do
        expect(subject.status).to eq(:ok)
      end
    end

    context 'with a failed search' do
      before { allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response_error) }

      it 'returns the response from the failed search' do
        expect_any_instance_of(MPI::Service).not_to receive(:add_person_proxy)
        expect(subject).to eq(profile_response_error)
      end
    end

    context 'with a failed add' do
      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:add_person_proxy).and_return(add_response_error)
      end

      it 'returns the failed add response' do
        expect_any_instance_of(MPIData).not_to receive(:add_ids)
        expect_any_instance_of(MPIData).not_to receive(:cache)
        response = subject
        expect(response.status).to eq(:server_error)
      end
    end
  end

  describe '#profile' do
    context 'when the cache is empty' do
      it 'caches and return an :ok response', :aggregate_failures do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response)
        expect(mvi).to receive(:save).once
        expect_any_instance_of(MPI::Service).to receive(:find_profile).once
        expect(mvi.status).to eq('OK')
        expect(mvi.send(:record_ttl)).to eq(86_400)
        expect(mvi.error).to be_nil
      end

      it 'returns an :error response but not cache it', :aggregate_failures do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response_error)
        expect(mvi).not_to receive(:save)
        expect_any_instance_of(MPI::Service).to receive(:find_profile).once
        expect(mvi.status).to eq('SERVER_ERROR')
        expect(mvi.error).to be_present
        expect(mvi.error.class).to eq Common::Exceptions::BackendServiceException
      end

      it 'returns a :not_found response and cache it for a shorter time', :aggregate_failures do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response_not_found)
        expect(mvi).to receive(:save).once
        expect_any_instance_of(MPI::Service).to receive(:find_profile).once
        expect(mvi.status).to eq('NOT_FOUND')
        expect(mvi.send(:record_ttl)).to eq(1800)
        expect(mvi.error).to be_present
        expect(mvi.error.class).to eq Common::Exceptions::BackendServiceException
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data for :ok response', :aggregate_failures do
        mvi.cache(user.uuid, profile_response)
        expect_any_instance_of(MPI::Service).not_to receive(:find_profile)
        expect(mvi.profile).to have_deep_attributes(mvi_profile)
        expect(mvi.error).to be_nil
      end

      it 'returns the cached data for :error response', :aggregate_failures do
        mvi.cache(user.uuid, profile_response_error)
        expect_any_instance_of(MPI::Service).not_to receive(:find_profile)
        expect(mvi.profile).to be_nil
        expect(mvi.error).to be_present
        expect(mvi.error.class).to eq Common::Exceptions::BackendServiceException
      end

      it 'returns the cached data for :not_found response', :aggregate_failures do
        mvi.cache(user.uuid, profile_response_not_found)
        expect_any_instance_of(MPI::Service).not_to receive(:find_profile)
        expect(mvi.profile).to be_nil
        expect(mvi.error).to be_present
        expect(mvi.error.class).to eq Common::Exceptions::BackendServiceException
      end
    end
  end

  describe 'correlation ids' do
    context 'with a successful response' do
      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response)
      end

      describe '#edipi' do
        it 'matches the response' do
          expect(mvi.edipi).to eq(profile_response.profile.edipi)
        end
      end

      describe '#edipis' do
        it 'matches the response' do
          expect(mvi.edipis).to eq(profile_response.profile.edipis)
        end
      end

      describe '#icn' do
        it 'matches the response' do
          expect(mvi.icn).to eq(profile_response.profile.icn)
        end
      end

      describe '#icn_with_aaid' do
        it 'matches the response' do
          expect(mvi.icn_with_aaid).to eq(profile_response.profile.icn_with_aaid)
        end
      end

      describe '#mhv_correlation_id' do
        it 'matches the response' do
          expect(mvi.mhv_correlation_id).to eq(profile_response.profile.mhv_correlation_id)
        end
      end

      describe '#participant_id' do
        it 'matches the response' do
          expect(mvi.participant_id).to eq(profile_response.profile.participant_id)
        end
      end

      describe '#participant_ids' do
        it 'matches the response' do
          expect(mvi.participant_ids).to eq(profile_response.profile.participant_ids)
        end
      end

      describe '#birls_id' do
        it 'matches the response' do
          expect(mvi.birls_id).to eq(profile_response.profile.birls_id)
        end
      end

      describe '#birls_ids' do
        it 'matches the response' do
          expect(mvi.birls_ids).to eq(profile_response.profile.birls_ids)
        end
      end

      describe '#mhv_ien' do
        it 'matches the response' do
          expect(mvi.mhv_ien).to eq(profile_response.profile.mhv_ien)
        end
      end

      describe '#mhv_iens' do
        it 'matches the response' do
          expect(mvi.mhv_iens).to eq(profile_response.profile.mhv_iens)
        end
      end

      describe '#vet360_id' do
        it 'matches the response' do
          expect(mvi.vet360_id).to eq(profile_response.profile.vet360_id)
        end
      end
    end

    context 'with an error response' do
      before do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response_error)
      end

      it 'captures the error in #error' do
        expect(mvi.error).to be_present
      end

      describe '#edipi' do
        it 'is nil' do
          expect(mvi.edipi).to be_nil
        end
      end

      describe '#icn' do
        it 'is nil' do
          expect(mvi.icn).to be_nil
        end
      end

      describe '#icn_with_aaid' do
        it 'is nil' do
          expect(mvi.icn_with_aaid).to be_nil
        end
      end

      describe '#mhv_correlation_id' do
        it 'is nil' do
          expect(mvi.mhv_correlation_id).to be_nil
        end
      end

      describe '#participant_id' do
        it 'is nil' do
          expect(mvi.participant_id).to be_nil
        end
      end
    end
  end

  describe '#add_ids' do
    let(:mvi) { MPIData.for_user(user.identity) }
    let(:response) do
      MPI::Responses::AddPersonResponse.new(
        status: :ok,
        parsed_codes: {
          birls_id: '1234567890',
          participant_id: '0987654321'
        }
      )
    end

    it 'updates the user profile and updates the cache' do
      allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response)
      expect_any_instance_of(MPIData).to receive(:cache).twice.and_call_original
      mvi.send(:add_ids, response)
      expect(user.participant_id).to eq('0987654321')
      expect(user.birls_id).to eq('1234567890')
    end
  end
end
