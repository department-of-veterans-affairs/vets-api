# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::UpdateUser do
  let(:user) { create(:user, :loa3, :with_terms_of_use_agreement) }
  let(:tud_account) { create(:tud_account, user_account_id: user.user_account_uuid) }

  before { allow(TestUserDashboard::TudAccount).to receive(:find_by).and_return(tud_account) }

  describe '#initialize' do
    it 'instantiates the test account by user_account_id' do
      TestUserDashboard::UpdateUser.new(user)

      expect(tud_account.user_account_id).to eq(user.user_account_uuid)
    end
  end

  describe '#call' do
    context 'when a user logs in' do
      before do
        tud_account.update(last_name: 'Changed', ssn: '123456789', services: [])
        @timestamp = Time.current.round(3)
        TestUserDashboard::UpdateUser.new(user).call(@timestamp)
      end

      it 'sets the test account to be checked out' do
        expect(tud_account.checkout_time).to eq(@timestamp)
      end
    end

    context 'when a user logs out' do
      before do
        tud_account.update(last_name: 'Changed', ssn: '123456789', services: [])
        TestUserDashboard::UpdateUser.new(user).call
      end

      it 'sets the test account to be checked in' do
        expect(tud_account.checkout_time).to be_nil
      end
    end
  end
end
