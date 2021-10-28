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

  describe '.create_if_needed!' do
    it 'creates an Account if one does not exist' do
      expect(Account.count).to eq 0

      attributes = OpenStruct.new({ idme_uuid: 'some-idme-uuid' })

      expect do
        Account.create_if_needed!(attributes)
      end.to change(Account, :count).by(1)
    end

    it 'does not create a second Account, matched on idme uuid' do
      idme_uuid = 'some-idme-uuid'
      attributes = OpenStruct.new({ idme_uuid: idme_uuid })
      create(:account, idme_uuid: idme_uuid)
      expect(Account.count).to eq 1

      expect do
        Account.create_if_needed!(attributes)
      end.not_to change(Account, :count)
    end

    it 'does not create a second Account, matched on sec id' do
      sec_id = 'some-sec-id'
      attributes = OpenStruct.new({ sec_id: sec_id })
      create(:account, sec_id: sec_id)
      expect(Account.count).to eq 1

      expect do
        Account.create_if_needed!(attributes)
      end.not_to change(Account, :count)
    end

    it 'does not create a second Account, matched on logingov_uuid' do
      logingov_uuid = 'some-logingov_uuid'
      attributes = OpenStruct.new({ logingov_uuid: logingov_uuid })
      create(:account, logingov_uuid: logingov_uuid)
      expect(Account.count).to eq 1

      expect do
        Account.create_if_needed!(attributes)
      end.not_to change(Account, :count)
    end

    it 'creates an Account on sec id if one does not exist' do
      expect(Account.count).to eq 0

      sec_id = 'some-sec-id'
      attributes = OpenStruct.new({ idme_uuid: nil, sec_id: sec_id })

      expect do
        acct = Account.create_if_needed!(attributes)
        expect(acct.sec_id).to eq sec_id
        expect(acct.idme_uuid).to eq nil
      end.to change(Account, :count).by(1)
    end

    it 'allows multiple records to have nil idme_uuid if sec_id is defined' do
      expect(Account.count).to eq 0
      first_sec_id = 'some-sec-id'
      another_sec_id = 'some-other-sec-id'

      first_attributes = OpenStruct.new({ idme_uuid: nil, sec_id: first_sec_id })
      second_attributes = OpenStruct.new({ idme_uuid: nil, sec_id: another_sec_id })

      expect do
        first_account = Account.create_if_needed!(first_attributes)
        second_account = Account.create_if_needed!(second_attributes)
        expect(first_account.sec_id).to eq first_sec_id
        expect(second_account.sec_id).to eq another_sec_id
        expect(first_account.idme_uuid).to eq nil
        expect(second_account.idme_uuid).to eq nil
      end.to change(Account, :count).by(2)
    end

    it 'matches on sec id with missing idme uuid' do
      sec_id = 'some-sec-id'
      attributes = OpenStruct.new({ idme_uuid: nil, sec_id: sec_id })
      create(:account, sec_id: sec_id)
      expect(Account.count).to eq 1

      expect do
        Account.create_if_needed!(attributes)
      end.not_to change(Account, :count)
    end

    it 'matches on logingov uuid with missing idme uuid and sec id' do
      logingov_uuid = 'some-logingov_uuid'
      attributes = OpenStruct.new({ idme_uuid: nil, sec_id: nil, logingov_uuid: logingov_uuid })
      create(:account, idme_uuid: nil, sec_id: nil, logingov_uuid: logingov_uuid)
      expect(Account.count).to eq 1

      expect do
        Account.create_if_needed!(attributes)
      end.not_to change(Account, :count)
    end

    it 'creates an Account on logingov uuid if one does not exist' do
      expect(Account.count).to eq 0

      logingov_uuid = 'some-logingov_uuid'
      attributes = OpenStruct.new({ idme_uuid: nil, sec_id: nil, logingov_uuid: logingov_uuid })

      expect do
        acct = Account.create_if_needed!(attributes)
        expect(acct.sec_id).to eq nil
        expect(acct.idme_uuid).to eq nil
        expect(acct.logingov_uuid).to eq logingov_uuid
      end.to change(Account, :count).by(1)
    end

    it 'issues a warning with multiple matching Accounts' do
      sec_id = 'some-sec-id'
      attributes = OpenStruct.new({ idme_uuid: nil, sec_id: sec_id })
      create(:account, idme_uuid: 'some-idme-uuid', sec_id: sec_id)
      create(:account, idme_uuid: 'another-idme-uuid', sec_id: sec_id)

      expect(Account).to receive(:log_message_to_sentry)

      expect do
        Account.create_if_needed!(attributes)
      end.not_to change(Account, :count)
    end

    it 'uses idme match with multiple matching Accounts' do
      sec_id = 'some-sec-id'
      idme_uuid = 'some-idme-uuid'
      attributes = OpenStruct.new({ idme_uuid: idme_uuid, sec_id: sec_id })

      create(:account, sec_id: sec_id)
      create(:account, idme_uuid: idme_uuid)

      acct = Account.create_if_needed!(attributes)
      expect(acct.idme_uuid).to eq(attributes.idme_uuid)
    end
  end

  describe '.update_if_needed!' do
    it 'does not update an Account that has yet to be saved' do
      expect(Account.count).to eq 0

      user = OpenStruct.new({ idme_uuid: 'kitty' })

      expect do
        Account.update_if_needed!(Account.new, user)
      end.not_to change(Account, :count)
    end

    it 'does not update the Account, as it hasnt changed' do
      user = OpenStruct.new({ idme_uuid: 'kitty' })
      acct = Account.create_if_needed!(user)

      expect(Account.count).to eq 1
      expect(Account).not_to receive(:log_message_to_sentry)
      expect(Account).not_to receive(:update)

      expect do
        Account.update_if_needed!(acct, user)
      end.not_to change(Account, :count)
    end

    it 'does update the Account' do
      user = OpenStruct.new({ edipi: 'some-edipi', icn: 'some-icn', sec_id: 'some-sec-id' })
      acct = create(:account, edipi: nil, icn: nil, sec_id: nil)

      expect(acct.edipi).to eq nil
      expect(acct.icn).to eq nil
      expect(acct.sec_id).to eq nil

      acct = Account.update_if_needed!(acct, user)

      expect(acct.edipi).to eq user.edipi
      expect(acct.icn).to eq user.icn
      expect(acct.sec_id).to eq user.sec_id
    end
  end

  describe '.create_by!' do
    let(:user) { OpenStruct.new({ idme_uuid: 'some-idme-uuid' }) }

    it "returns the user's db Account record", :aggregate_failures do
      record = Account.create_by! user

      expect(record).to eq Account.find_by(idme_uuid: user.idme_uuid)
      expect(record.class).to eq Account
    end
  end

  describe 'update' do
    let(:user) { OpenStruct.new({ idme_uuid: 'some-idme-uuid', sec_id: nil }) }
    let(:new_secid) { '9999999' }
    let(:user_delta) { OpenStruct.new({ sec_id: new_secid }) }

    it 'writes updates to database' do
      original_acct = Account.create_by! user
      updated_acct = Account.update_if_needed!(original_acct, user_delta)
      expect(updated_acct.sec_id).to eq new_secid
    end

    it 'does not overwrite populated fields with nil values' do
      original_acct = Account.create_by! user_delta
      updated_acct = Account.update_if_needed!(original_acct, user)
      expect(updated_acct.sec_id).to be_present
    end
  end
end
