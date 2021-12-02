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

  it 'enforces sec_id uniqueness when idme_uuid is blank' do
    expect(Account.count).to eq 0
    sec_id = 'some-sec-id'

    expect do
      first_account = Account.new(sec_id: sec_id)
      second_account = Account.new(sec_id: sec_id)

      first_account.save
      second_account.save
      expect(first_account.sec_id).to eq sec_id
      expect(second_account.sec_id).to eq sec_id
      expect(first_account.idme_uuid).to eq nil
      expect(second_account.idme_uuid).to eq nil
      expect(first_account.valid?).to eq true
      expect(second_account.valid?).to eq false
    end.to change(Account, :count).by(1)
  end

  describe '.idme_uuid_match' do
    it 'returns only accounts with matching idme_uuid' do
      find_me = create :account
      dont_find_me = create :account
      accounts = Account.idme_uuid_match(find_me.idme_uuid)
      expect(accounts).to include(find_me)
      expect(accounts).not_to include(dont_find_me)
    end

    it 'returns no records with a nil idme_uuid' do
      create :account # account to not find
      expect(Account.idme_uuid_match(nil)).to be_empty
    end
  end

  describe '.sec_id_match' do
    it 'returns only accounts with matching sec_id' do
      find_me = create :account
      find_me.sec_id = SecureRandom.uuid
      find_me.save!
      dont_find_me = create :account
      dont_find_me.sec_id = SecureRandom.uuid
      dont_find_me.save!
      accounts = Account.sec_id_match(find_me.sec_id)
      expect(accounts).to include(find_me)
      expect(accounts).not_to include(dont_find_me)
    end

    it 'returns no records with a nil sec_id' do
      create :account # account to not find
      expect(Account.sec_id_match(nil)).to be_empty
    end
  end

  describe '.logingov_uuid_match' do
    it 'returns only accounts with matching logingov_uuid' do
      find_me = create :account
      find_me.logingov_uuid = SecureRandom.uuid
      find_me.save!
      dont_find_me = create :account
      dont_find_me.logingov_uuid = SecureRandom.uuid
      dont_find_me.save!
      accounts = Account.logingov_uuid_match(find_me.logingov_uuid)
      expect(accounts).to include(find_me)
      expect(accounts).not_to include(dont_find_me)
    end

    it 'returns no records with a nil logingov_uuid' do
      create :account # account to not find
      expect(Account.logingov_uuid_match(nil)).to be_empty
    end
  end
end
