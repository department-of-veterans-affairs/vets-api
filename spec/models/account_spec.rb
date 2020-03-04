# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account, type: :model do
  it 'does not allow the uuid to be updated' do
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

    it 'does not create a second Account, matched on idme uuid' do
      user = create(:user, :accountable)
      expect(Account.count).to eq 1

      expect do
        Account.create_if_needed!(user)
      end.not_to change(Account, :count)
    end

    it 'does not create a second Account, matched on sec id' do
      user = create(:user, :accountable_with_sec_id)
      expect(Account.count).to eq 1

      expect do
        Account.create_if_needed!(user)
      end.not_to change(Account, :count)
    end

    it 'issues a warning with multiple matching Accounts' do
      user = create(:user, :accountable)
      create(:user, :accountable_with_sec_id)

      expect(Account).to receive(:log_message_to_sentry)

      expect do
        Account.create_if_needed!(user)
      end.not_to change(Account, :count)
    end
  end

  describe '.update_if_needed!' do
    it 'does not update an Account that has yet to be saved' do
      expect(Account.count).to eq 0

      user = create(:user, :loa3)

      expect do
        Account.update_if_needed!(Account.new, user)
      end.not_to change(Account, :count)
    end

    it 'does not update the Account, as it hasnt changed' do
      user = create(:user, :loa3)
      acct = Account.create_if_needed!(user)

      expect(Account.count).to eq 1
      expect(Account).not_to receive(:log_message_to_sentry)
      expect(Account).not_to receive(:update)

      expect do
        Account.update_if_needed!(acct, user)
      end.not_to change(Account, :count)
    end

    it 'does update the Account' do
      user = create(:user, :accountable)
      acct = Account.first

      expect(acct.edipi).to eq nil
      expect(acct.icn).to eq nil
      expect(acct.sec_id).to eq nil

      acct = Account.update_if_needed!(acct, user)

      expect(acct.edipi).to eq user.edipi
      expect(acct.icn).to eq user.icn
      expect(acct.sec_id).to eq user.sec_id
    end
  end

  describe 'Account factory' do
    it 'generates a valid factory' do
      account = create :account

      expect(account).to be_valid
    end
  end

  describe 'callbacks' do
    describe 'before_create' do
      let(:account) { create :account }

      context 'when uuid is not present in the database' do
        it 'creates a unique uuid' do
          expect(account).to be_valid
        end
      end

      context 'when uuid *is* already present in the database' do
        it 'creates a valid record with a unique uuid', :aggregate_failures do
          existing_uuid = account.uuid
          new_account   = create :account, uuid: existing_uuid

          expect(new_account).to be_valid
          expect(existing_uuid).not_to eq new_account.uuid
        end
      end
    end
  end

  describe '.cache_or_create_by!' do
    let(:user) { build(:user, :loa3) }

    it 'first attempts to fetch the Account record from the Redis cache' do
      expect(Account).to receive(:do_cached_with) { Account.create(idme_uuid: user.uuid) }

      Account.cache_or_create_by! user
    end

    it "returns the user's db Account record", :aggregate_failures do
      record = Account.cache_or_create_by! user

      expect(record).to eq Account.find_by(idme_uuid: user.uuid)
      expect(record.class).to eq Account
    end
  end

  describe 'cache write-through on update' do
    let(:user) { build(:user_with_no_secid) }
    let(:new_secid) { '9999999' }
    let(:user_delta) { build(:user, :loa3) }

    it 'writes updates to database AND cache' do
      original_acct = Account.cache_or_create_by! user
      user.mvi.profile.sec_id = new_secid
      updated_acct = Account.update_if_needed!(original_acct, user_delta)
      expect(updated_acct.sec_id).to eq new_secid

      # Use do_cached_with to fetch cached model only
      cached_acct = Account.do_cached_with(key: user.uuid)
      expect(cached_acct.sec_id).to eq new_secid
    end

    it 'does not overwrite populated fields with nil values' do
      original_acct = Account.cache_or_create_by! user_delta
      updated_acct = Account.update_if_needed!(original_acct, user)
      expect(updated_acct.sec_id).to be_present

      # Use do_cached_with to fetch cached model only
      cached_acct = Account.do_cached_with(key: user.uuid)
      expect(cached_acct.sec_id).to be_present
    end
  end
end
