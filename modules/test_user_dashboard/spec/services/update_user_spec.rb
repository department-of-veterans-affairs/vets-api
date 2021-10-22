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

    context 'when user has incomplete attributes' do
      let(:user_ssn) { '343434343' }
      let(:user) { create(:user, last_name: nil, ssn: user_ssn) }
      let(:tud_account) { create(:tud_account, account_uuid: user.account_uuid, last_name: 'some-last-name') }

      before do
        @timestamp = Time.current
        TestUserDashboard::UpdateUser.new(user).call(@timestamp)
      end

      it 'sets the test account to be checked out' do
        expect(tud_account.checkout_time).to eq(@timestamp)
      end

      it 'updates the test account only with the attributes that are presented' do
        expect(tud_account.last_name).to eq(user.last_name)
        expect(tud_account.ssn.to_s).to eq(user_ssn)
      end
    end

    context 'when user has invalid attributes' do
      let(:update_user_instance) { TestUserDashboard::UpdateUser.new(user) }
      let(:timestamp) { Time.now.utc }
      let(:tud_user_values) { tud_account.user_values(user).merge(checkout_time: timestamp) }

      before do
        allow(tud_account).to receive(:update).and_return(false)
      end

      it 'does not update any attributes' do
        update_user_instance.call(timestamp)
        expect(tud_account.last_name).not_to eq(user.last_name)
        expect(tud_account.ssn.to_s).not_to eq(user.ssn)
      end

      it 'logs a message to sentry' do
        expect(update_user_instance).to receive(:log_message_to_sentry).with(
          '[TestUserDashboard] UpdateUser invalid update',
          :warn,
          tud_user_values
        )
        update_user_instance.call(timestamp)
      end
    end
  end
end
