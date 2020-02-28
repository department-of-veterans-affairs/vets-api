# frozen_string_literal: true

require 'rails_helper'
require 'common/models/concerns/active_record_cache_aside'

describe Common::ActiveRecordCacheAside do
  let(:user) { build(:user, :loa3) }
  let(:serialized_record) { Marshal.dump(build(:account, idme_uuid: user.uuid)) }
  let(:redis_key) { "user-account-details:#{user.uuid}" }
  let(:ttl) { REDIS_CONFIG['user_account_details']['each_ttl'] }

  describe '.do_cached_with' do
    context 'when a db record is present in the cache' do
      before do
        allow_any_instance_of(Redis).to receive(:get).and_return(serialized_record)
      end

      it 'retrieves the db record from the cache' do
        expect(Marshal).to receive(:load).with(serialized_record)

        Account.cache_or_create_by! user
      end

      it 'does not attempt to re-cache the record' do
        expect(Account).not_to receive(:cache_record)

        Account.cache_or_create_by! user
      end
    end

    context 'when the db record is not present in the cache' do
      it 'caches the record' do
        expect(Account).to receive(:cache_record)

        Account.cache_or_create_by! user
      end

      it 'returns an ActiveRecord::Base database record', :aggregate_failures do
        record = Account.cache_or_create_by! user

        expect(record).to eq Account.find_by(idme_uuid: user.uuid)
        expect(record).to be_a_kind_of ActiveRecord::Base
      end
    end
  end

  describe '.cache_record' do
    before do
      allow(Marshal).to receive(:dump).and_return(serialized_record)
    end

    it 'caches a serialized db record in Redis' do
      expect_any_instance_of(Redis).to receive(:set).with(redis_key, serialized_record)

      Account.cache_or_create_by! user
    end

    it 'sets the expiration when caching a serialized db record in Redis' do
      expect_any_instance_of(Redis).to receive(:expire).with(redis_key, ttl)

      Account.cache_or_create_by! user
    end
  end
end
