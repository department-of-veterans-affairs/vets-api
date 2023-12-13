# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::UserInfo, type: :model do
  describe 'create' do
    it 'creates a new record' do
      expect do
        attributes = FactoryBot.attributes_for(:vye_user_info)
        Vye::UserInfo.create!(attributes)
      end.to change(Vye::UserInfo, :count).by(1)
    end
  end

  describe 'find_by_user after ICN is recorded' do
    let!(:user) { create(:evss_user, :loa3) }
    let!(:user_info) { FactoryBot.create(:vye_user_info, icn: user.icn) }

    it 'finds the user info by icn' do
      expect(Vye::UserInfo.find_and_update_icn(user:)).to eq(user_info)
    end
  end

  describe 'find_by_user before ICN is recorded' do
    let!(:user) { create(:evss_user, :loa3) }
    let!(:user_info) { FactoryBot.create(:vye_user_info, icn: nil, ssn: user.ssn) }

    it 'finds the user info by ssn' do
      u = Vye::UserInfo.find_and_update_icn(user:)
      expect(u).to eq(user_info)
      expect(u.icn_in_database).to eq(user.icn)
    end
  end
end
