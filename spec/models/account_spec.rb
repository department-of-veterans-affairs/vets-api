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
end
