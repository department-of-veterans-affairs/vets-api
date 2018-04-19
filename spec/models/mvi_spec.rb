# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe Mvi, skip_mvi: true do
  let(:user) { build(:user, :loa3) }
  let(:mvi) { Mvi.for_user(user) }
  let(:mvi_profile) { build(:mvi_profile) }
  let(:profile_response) do
    MVI::Responses::FindProfileResponse.new(
      status: MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
      profile: mvi_profile
    )
  end
  let(:profile_response_error) do
    MVI::Responses::FindProfileResponse.with_server_error
  end

  describe '.new' do
    it 'creates an instance with user attributes' do
      expect(mvi.user).to eq(user)
    end
  end

  describe '#profile' do
    context 'when the cache is empty' do
      it 'should cache and return the response' do
        allow_any_instance_of(MVI::Service).to receive(:find_profile).and_return(profile_response)
        expect(mvi.redis_namespace).to receive(:set).once
        expect_any_instance_of(MVI::Service).to receive(:find_profile).once
        expect(mvi.status).to eq('OK')
      end
    end

    context 'when there is cached data' do
      it 'returns the cached data' do
        mvi.cache(user.uuid, profile_response)
        expect_any_instance_of(MVI::Service).to_not receive(:find_profile)
        expect(mvi.profile).to have_deep_attributes(mvi_profile)
      end
    end
  end

  describe 'correlation ids' do
    context 'with a succesful response' do
      before(:each) do
        allow_any_instance_of(MVI::Service).to receive(:find_profile).and_return(profile_response)
      end

      describe '#edipi' do
        it 'should match the response' do
          expect(mvi.edipi).to eq(profile_response.profile.edipi)
        end
      end
      describe '#icn' do
        it 'should match the response' do
          expect(mvi.icn).to eq(profile_response.profile.icn)
        end
      end
      describe '#mhv_correlation_id' do
        it 'should match the response' do
          expect(mvi.mhv_correlation_id).to eq(profile_response.profile.mhv_correlation_id)
        end
      end
      describe '#participant_id' do
        it 'should match the response' do
          expect(mvi.participant_id).to eq(profile_response.profile.participant_id)
        end
      end
      describe '#historical_icns' do
        it 'should match the response' do
          expect(mvi.historical_icns).to eq(profile_response.profile.historical_icns)
        end
      end
      describe '#vet360_id' do
        it 'should match the response' do
          expect(mvi.vet360_id).to eq(profile_response.profile.vet360_id)
        end
      end
    end

    context 'with an error response' do
      before(:each) do
        allow_any_instance_of(MVI::Service).to receive(:find_profile).and_return(profile_response_error)
      end

      describe '#edipi' do
        it 'should be nil' do
          expect(mvi.edipi).to be_nil
        end
      end
      describe '#icn' do
        it 'should be nil' do
          expect(mvi.icn).to be_nil
        end
      end
      describe '#mhv_correlation_id' do
        it 'should be nil' do
          expect(mvi.mhv_correlation_id).to be_nil
        end
      end
      describe '#participant_id' do
        it 'should be nil' do
          expect(mvi.participant_id).to be_nil
        end
      end
    end
  end
end
