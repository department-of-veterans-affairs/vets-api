# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Account, type: :model do
  it 'does not allow the uuid to be updated' do
    account  = create(:account)
    uuid     = account.uuid
    new_uuid = '9166953e-e71f-44aa-ba39-a6fe973a177e'

    account.update!(uuid: new_uuid)

    expect(account.reload.uuid).to eq uuid
  end

  it 'enforces sec_id uniqueness when idme_uuid is blank' do
    expect(Account.count).to eq 0
    sec_id = 'some-sec-id'

    expect do
      first_account = Account.new(sec_id:)
      second_account = Account.new(sec_id:)

      first_account.save
      second_account.save
      expect(first_account.sec_id).to eq sec_id
      expect(second_account.sec_id).to eq sec_id
      expect(first_account.idme_uuid).to be_nil
      expect(second_account.idme_uuid).to be_nil
      expect(first_account.valid?).to be true
      expect(second_account.valid?).to be false
    end.to change(Account, :count).by(1)
  end

  describe '.idme_uuid_match' do
    it 'returns only accounts with matching idme_uuid' do
      find_me = create(:account)
      dont_find_me = create(:account)
      accounts = Account.idme_uuid_match(find_me.idme_uuid)
      expect(accounts).to include(find_me)
      expect(accounts).not_to include(dont_find_me)
    end

    it 'returns no records with a nil idme_uuid' do
      create(:account) # account to not find
      expect(Account.idme_uuid_match(nil)).to be_empty
    end
  end

  describe '.sec_id_match' do
    it 'returns only accounts with matching sec_id' do
      find_me = create(:account)
      find_me.sec_id = SecureRandom.uuid
      find_me.save!
      dont_find_me = create(:account)
      dont_find_me.sec_id = SecureRandom.uuid
      dont_find_me.save!
      accounts = Account.sec_id_match(find_me.sec_id)
      expect(accounts).to include(find_me)
      expect(accounts).not_to include(dont_find_me)
    end

    it 'returns no records with a nil sec_id' do
      create(:account) # account to not find
      expect(Account.sec_id_match(nil)).to be_empty
    end
  end

  describe '.logingov_uuid_match' do
    it 'returns only accounts with matching logingov_uuid' do
      find_me = create(:account)
      find_me.logingov_uuid = SecureRandom.uuid
      find_me.save!
      dont_find_me = create(:account)
      dont_find_me.logingov_uuid = SecureRandom.uuid
      dont_find_me.save!
      accounts = Account.logingov_uuid_match(find_me.logingov_uuid)
      expect(accounts).to include(find_me)
      expect(accounts).not_to include(dont_find_me)
    end

    it 'returns no records with a nil logingov_uuid' do
      create(:account) # account to not find
      expect(Account.logingov_uuid_match(nil)).to be_empty
    end
  end

  describe '.lookup_by_user_uuid' do
    let!(:find_me) { create(:account, idme_uuid:, logingov_uuid:, icn:) }
    let!(:dont_find_me) { create(:account, idme_uuid: other_idme_uuid, logingov_uuid: other_logingov_uuid) }
    let(:idme_uuid) { 'some-idme-uuid' }
    let(:logingov_uuid) { 'some-logingov-uuid' }
    let(:other_idme_uuid) { 'some-other-idme-uuid' }
    let(:other_logingov_uuid) { 'some-other-logingov-uuid' }
    let(:icn) { 'some-icn' }

    it 'returns Account matching given idme_uuid' do
      expect(Account.lookup_by_user_uuid(find_me.idme_uuid)).to eq find_me
    end

    it 'returns Account matching given logingov_uuid' do
      expect(Account.lookup_by_user_uuid(find_me.logingov_uuid)).to eq find_me
    end

    it 'returns nil when given bogus user_uuid' do
      expect(Account.lookup_by_user_uuid('bogus-1234')).to be_nil
    end

    it 'returns nil when given blank user_uuid' do
      expect(Account.lookup_by_user_uuid('')).to be_nil
    end

    it 'returns nil when given nil user_uuid' do
      expect(Account.lookup_by_user_uuid(nil)).to be_nil
    end

    context 'when another account has a logingov_uuid matching user_uuid' do
      let(:user_uuid) { 'some-user-uuid' }
      let(:idme_uuid) { user_uuid }
      let(:other_logingov_uuid) { user_uuid }

      it 'returns the account found by idme_uuid' do
        expect(Account.lookup_by_user_uuid(user_uuid)).to eq find_me
      end
    end

    context 'when a user account has a uuid matching user_uuid' do
      let(:user_uuid) { create(:user_account, icn:).id }

      it 'returns the account that matches the icn in the user account' do
        expect(Account.lookup_by_user_uuid(user_uuid)).to eq find_me
      end
    end
  end

  describe '.lookup_by_user_account_uuid' do
    let!(:find_me) { create(:account) }
    let!(:dont_find_me) { create(:account) }

    context 'when user_uuid matches a UserAccount' do
      let(:user_uuid) { create(:user_account, icn:).id }
      let!(:account) { create(:account, icn:) }

      context 'and matching UserAccount has an icn' do
        let(:icn) { 'some-icn' }

        it 'returns first Account with matching icn' do
          expect(Account.lookup_by_user_account_uuid(user_uuid)).to eq(account)
        end
      end

      context 'and matching UserAccount does not have an icn' do
        let(:icn) { nil }

        it 'returns nil' do
          expect(Account.lookup_by_user_account_uuid(user_uuid)).to be_nil
        end
      end
    end

    context 'when user_uuid does not match a UserAccount' do
      let(:user_uuid) { 'some-user-uuid' }

      it 'returns nil' do
        expect(Account.lookup_by_user_account_uuid(user_uuid)).to be_nil
      end
    end
  end
end
