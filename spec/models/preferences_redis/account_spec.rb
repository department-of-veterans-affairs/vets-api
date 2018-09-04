# frozen_string_literal: true

require 'rails_helper'
require 'common/exceptions'

describe PreferencesRedis::Account do
  let(:user) { build(:user, :accountable) }

  describe '.for_user' do
    context 'when the cache is empty' do
      it 'should attempt to cache the user account', :aggregate_failures do
        expect_any_instance_of(PreferencesRedis::Account).to receive(:cache).once

        PreferencesRedis::Account.for_user(user)
      end
    end

    context 'when the user account is cached' do
      it 'does not send :cache message' do
        redis_account = PreferencesRedis::Account.for_user(user)
        redis_account.cache(user.uuid, redis_account.response)

        expect_any_instance_of(PreferencesRedis::Account).to_not receive(:cache)
        PreferencesRedis::Account.for_user(user)
      end

      it 'returns the cached user account data' do
        response = PreferencesRedis::Account.for_user(user).response

        expect(response.user_account.dig('uuid')).to eq user.account.uuid
      end
    end
  end

  describe '#response' do
    it 'responds with the correct user account attributes' do
      response = PreferencesRedis::Account.for_user(user).response

      cached_uuid = response.user_account.dig('uuid')

      expect(cached_uuid).to eq (user.account.uuid)
    end
  end
end