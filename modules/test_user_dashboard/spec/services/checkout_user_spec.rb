# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::CheckoutUser do
  let(:tud_account) { create(:tud_account, account_uuid: '9999999') }

  describe '#initialize' do
    it 'instantiates the test account by account_uuid' do
      expect(tud_account.account_uuid).to eq('9999999')
    end
  end

  describe '#call' do
    it 'sets the test account to be checked out' do
      TestUserDashboard::CheckoutUser.new(tud_account.account_uuid).call
      expect(TestUserDashboard::CheckoutUser.new(tud_account.account_uuid).tud_account.checkout_time)
        .to be_within(1.second).of Time.current
    end
  end
end
