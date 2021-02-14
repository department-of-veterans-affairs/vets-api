# frozen_string_literal: true

require 'rails_helper'

describe TestUserDashboard::CheckinUser do
  let(:tud_account) { create(:tud_account, account_uuid: '1111111') }

  describe '#initialize' do
    it 'instantiates the test account by account_uuid' do
      expect(tud_account.account_uuid).to eq('1111111')
    end
  end

  describe '#call' do
    it 'sets the test account to be checked in' do
      TestUserDashboard::CheckinUser.new(tud_account.account_uuid).call
      expect(TestUserDashboard::CheckinUser.new(tud_account.account_uuid).tud_account.checkout_time)
        .to eq(nil)
    end
  end
end
