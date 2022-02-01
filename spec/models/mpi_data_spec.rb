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
  let(:mvi_codes) do
    {
      birls_id: '111985523',
      participant_id: '32397028'
    }
  end
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
      status: MPI::Responses::AddPersonResponse::RESPONSE_STATUS[:ok],
      mvi_codes: mvi_codes
    )
  end
  let(:add_response_error) { MPI::Responses::AddPersonResponse.with_server_error(server_error_exception) }
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

  describe '#add_person' do
    context 'with a successful add' do
      let(:given_names) { %w[kitty puppy] }
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
      let(:icn_with_aaid) { 'some-icn-with-aaid' }
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
              icn_with_aaid: icn_with_aaid,
              edipi: edipi,
              search_token: search_token,
              ssn: ssn,
              person_types: person_types,
              gender: gender)
      end
      let(:expected_user_identity) do
        build(:user_identity,
              :loa3,
              first_name: given_names.first,
              middle_name: given_names.last,
              last_name: family_name,
              suffix: suffix,
              birth_date: birth_date,
              address: address,
              icn_with_aaid: icn_with_aaid,
              edipi: edipi,
              search_token: search_token,
              gender: gender,
              ssn: ssn,
              phone: phone,
              person_types: person_types,
              idme_uuid: user.idme_uuid)
      end

      it 'copies relevant results from orchestration search to fields for add person call' do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:add_person).and_return(add_response)
        mvi.add_person
        expect(mvi.user_identity.to_h).to include(expected_user_identity.to_h)
      end

      it 'returns the successful response' do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:add_person).and_return(add_response)
        expect_any_instance_of(MPIData).to receive(:add_ids).once.and_call_original
        expect_any_instance_of(MPIData).to receive(:cache).once.and_call_original
        response = mvi.add_person
        expect(response.status).to eq('OK')
      end
    end

    context 'with a failed search' do
      it 'returns the failed search response' do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response_error)
        response = mvi.add_person
        expect_any_instance_of(MPI::Service).not_to receive(:add_person)
        expect(response.status).to eq('SERVER_ERROR')
      end
    end

    context 'with a failed add' do
      it 'returns the failed add response' do
        allow_any_instance_of(MPI::Service).to receive(:find_profile).and_return(profile_response)
        allow_any_instance_of(MPI::Service).to receive(:add_person).and_return(add_response_error)
        expect_any_instance_of(MPIData).not_to receive(:add_ids)
        expect_any_instance_of(MPIData).not_to receive(:cache)
        response = mvi.add_person
        expect(response.status).to eq('SERVER_ERROR')
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
        status: 'OK',
        mvi_codes: {
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
