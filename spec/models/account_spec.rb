# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account, type: :model do
  it 'should not allow the uuid to be updated' do
    account  = create :account
    uuid     = account.uuid
    new_uuid = '9166953e-e71f-44aa-ba39-a6fe973a177e'

    account.update!(uuid: new_uuid)

    expect(account.reload.uuid).to eq uuid
  end

  describe '.create_if_needed!' do
    it 'creates an Account if one does not exist' do
      expect(Account.count).to eq 0

      user = create(:user, :loa3)

      expect do
        Account.create_if_needed!(user)
      end.to change(Account, :count).by(1)
    end

    it 'should not create a second Account' do
      user = create(:user, :accountable)
      expect(Account.count).to eq 1

      expect do
        Account.create_if_needed!(user)
      end.not_to change(Account, :count)
    end
  end

  describe 'Account factory' do
    it 'should generate a valid factory' do
      account = create :account

      expect(account).to be_valid
    end
  end

  describe 'callbacks' do
    describe 'before_create' do
      let(:account) { create :account }

      context 'when uuid is not present in the database' do
        it 'should create a unique uuid' do
          expect(account).to be_valid
        end
      end

      context 'when uuid *is* already present in the database' do
        it 'should create a valid record with a unique uuid', :aggregate_failures do
          existing_uuid = account.uuid
          new_account   = create :account, uuid: existing_uuid

          expect(new_account).to be_valid
          expect(existing_uuid).to_not eq new_account.uuid
        end
      end
    end
  end

  describe '.cache_or_create_by!' do
    let(:user) { build(:user, :loa3) }

    it 'first attempts to fetch the Account record from the Redis cache' do
      expect(Account).to receive(:do_cached_with)

      Account.cache_or_create_by! user
    end

    it "returns the user's db Account record", :aggregate_failures do
      record = Account.cache_or_create_by! user

      expect(record).to eq Account.find_by(idme_uuid: user.uuid)
      expect(record.class).to eq Account
    end
  end
end
