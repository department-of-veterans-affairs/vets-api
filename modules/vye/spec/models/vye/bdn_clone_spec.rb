# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BdnClone, type: :model do
  describe 'create' do
    let(:attributes) { FactoryBot.attributes_for(:vye_bdn_clone_base) }

    it 'creates a record' do
      expect do
        described_class.create!(attributes)
      end.to change(described_class, :count).by(1)
    end
  end

  describe 'activation' do
    let!(:vbc0) { FactoryBot.create(:vye_bdn_clone_base, is_active: nil) }
    let!(:vbc1) { FactoryBot.create(:vye_bdn_clone_base, is_active: true) }
    let!(:vbc2) { FactoryBot.create(:vye_bdn_clone_base, is_active: false) }

    let!(:vup1) { FactoryBot.create(:vye_user_profile) }
    let!(:vup2) { FactoryBot.create(:vye_user_profile) }
    let!(:vup3) { FactoryBot.create(:vye_user_profile) }
    let!(:vup4) { FactoryBot.create(:vye_user_profile) }
    let!(:vup5) { FactoryBot.create(:vye_user_profile) }
    let!(:vup6) { FactoryBot.create(:vye_user_profile) }
    let!(:vup7) { FactoryBot.create(:vye_user_profile) }

    let!(:vui01) { FactoryBot.create(:vye_user_info, user_profile: vup1, bdn_clone: vbc0, bdn_clone_active: nil) }
    let!(:vui02) { FactoryBot.create(:vye_user_info, user_profile: vup2, bdn_clone: vbc0, bdn_clone_active: nil) }
    let!(:vui03) { FactoryBot.create(:vye_user_info, user_profile: vup3, bdn_clone: vbc0, bdn_clone_active: nil) }

    let!(:vui11) { FactoryBot.create(:vye_user_info, user_profile: vup1, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui12) { FactoryBot.create(:vye_user_info, user_profile: vup2, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui13) { FactoryBot.create(:vye_user_info, user_profile: vup3, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui14) { FactoryBot.create(:vye_user_info, user_profile: vup4, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui15) { FactoryBot.create(:vye_user_info, user_profile: vup5, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui16) { FactoryBot.create(:vye_user_info, user_profile: vup6, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui17) { FactoryBot.create(:vye_user_info, user_profile: vup7, bdn_clone: vbc1, bdn_clone_active: true) }

    let!(:vui21) { FactoryBot.create(:vye_user_info, user_profile: vup1, bdn_clone: vbc2, bdn_clone_active: nil) }
    let!(:vui22) { FactoryBot.create(:vye_user_info, user_profile: vup2, bdn_clone: vbc2, bdn_clone_active: nil) }
    let!(:vui23) { FactoryBot.create(:vye_user_info, user_profile: vup3, bdn_clone: vbc2, bdn_clone_active: nil) }
    let!(:vui24) { FactoryBot.create(:vye_user_info, user_profile: vup4, bdn_clone: vbc2, bdn_clone_active: nil) }
    let!(:vui25) { FactoryBot.create(:vye_user_info, user_profile: vup5, bdn_clone: vbc2, bdn_clone_active: nil) }

    it 'activates the correct records' do
      expect(Vye::UserInfo.where(bdn_clone_active: [nil, false]).count).to eq(8)
      expect(Vye::UserInfo.where(bdn_clone_active: true).count).to eq(7)
      expect(described_class.injested?).to eq(true)
      described_class.activate_injested!
      expect(Vye::UserInfo.where(bdn_clone_active: [nil, false]).count).to eq(10)
      expect(Vye::UserInfo.where(bdn_clone_active: true).count).to eq(5)
    end
  end
end
