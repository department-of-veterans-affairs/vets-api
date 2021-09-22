# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::UpdateUser do
  let(:user) { create(:user) }
  let(:tud_account) { create(:tud_account, account_uuid: user.account_uuid) }

  before { allow(TestUserDashboard::TudAccount).to receive(:find_by).and_return(tud_account) }

  describe '#initialize' do
    it 'instantiates the test account by account_uuid' do
      TestUserDashboard::UpdateUser.new(user)

      expect(tud_account.account_uuid).to eq(user.account_uuid)
    end
  end

  describe '#call' do
    context 'when a user logs in' do
      before do
        tud_account.update(last_name: 'Changed', ssn: '123456789', services: [])
        @timestamp = Time.current
        TestUserDashboard::UpdateUser.new(user).call(@timestamp)
      end

      it 'sets the test account to be checked out' do
        expect(tud_account.checkout_time).to eq(@timestamp)
      end

      it 'updates the test account with user account values' do
        expect(tud_account.last_name).to eq(user.last_name)
        expect(tud_account.ssn.to_s).to eq(user.ssn)
        expect(tud_account.services).to eq(Users::Services.new(user).authorizations)
      end
    end

    context 'when a user logs out' do
      before do
        tud_account.update(last_name: 'Changed', ssn: '123456789', services: [])
        TestUserDashboard::UpdateUser.new(user).call
      end

      it 'sets the test account to be checked in' do
        expect(tud_account.checkout_time).to eq(nil)
      end

      it 'updates the test account with user account values' do
        expect(tud_account.last_name).to eq(user.last_name)
        expect(tud_account.ssn.to_s).to eq(user.ssn)
        expect(tud_account.services).to eq(Users::Services.new(user).authorizations)
      end
    end
  end
end
