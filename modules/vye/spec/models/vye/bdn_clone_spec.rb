# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BdnClone, type: :model do
  describe 'create' do
    let(:attributes) { attributes_for(:vye_bdn_clone_base) }

    it 'creates a record' do
      expect do
        described_class.create!(attributes)
      end.to change(described_class, :count).by(1)
    end
  end

  describe 'non-activation' do
    let!(:vbc0) { create(:vye_bdn_clone_base, is_active: nil) }

    it "doesn't activate records" do
      expect do
        described_class.activate_injested!
      end.to raise_error(Vye::BndCloneNotFound)
    end
  end

  describe 'activation' do
    let!(:vbc0) { create(:vye_bdn_clone_base, is_active: nil) }
    let!(:vbc1) { create(:vye_bdn_clone_base, is_active: true) }
    let!(:vbc2) { create(:vye_bdn_clone_base, is_active: false) }

    let!(:vup1) { create(:vye_user_profile) }
    let!(:vup2) { create(:vye_user_profile) }
    let!(:vup3) { create(:vye_user_profile) }
    let!(:vup4) { create(:vye_user_profile) }
    let!(:vup5) { create(:vye_user_profile) }
    let!(:vup6) { create(:vye_user_profile) }
    let!(:vup7) { create(:vye_user_profile) }

    let!(:vui01) { create(:vye_user_info, user_profile: vup1, bdn_clone: vbc0, bdn_clone_active: nil) }
    let!(:vui02) { create(:vye_user_info, user_profile: vup2, bdn_clone: vbc0, bdn_clone_active: nil) }
    let!(:vui03) { create(:vye_user_info, user_profile: vup3, bdn_clone: vbc0, bdn_clone_active: nil) }

    let!(:vui11) { create(:vye_user_info, user_profile: vup1, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui12) { create(:vye_user_info, user_profile: vup2, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui13) { create(:vye_user_info, user_profile: vup3, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui14) { create(:vye_user_info, user_profile: vup4, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui15) { create(:vye_user_info, user_profile: vup5, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui16) { create(:vye_user_info, user_profile: vup6, bdn_clone: vbc1, bdn_clone_active: true) }
    let!(:vui17) { create(:vye_user_info, user_profile: vup7, bdn_clone: vbc1, bdn_clone_active: true) }

    let!(:vui21) { create(:vye_user_info, user_profile: vup1, bdn_clone: vbc2, bdn_clone_active: nil) }
    let!(:vui22) { create(:vye_user_info, user_profile: vup2, bdn_clone: vbc2, bdn_clone_active: nil) }
    let!(:vui23) { create(:vye_user_info, user_profile: vup3, bdn_clone: vbc2, bdn_clone_active: nil) }
    let!(:vui24) { create(:vye_user_info, user_profile: vup4, bdn_clone: vbc2, bdn_clone_active: nil) }
    let!(:vui25) { create(:vye_user_info, user_profile: vup5, bdn_clone: vbc2, bdn_clone_active: nil) }

    it 'activates the correct records' do
      expect(Vye::UserInfo.where(bdn_clone_active: [nil, false]).count).to eq(8)
      expect(Vye::UserInfo.where(bdn_clone_active: true).count).to eq(7)

      expect do
        described_class.activate_injested!
      end.not_to raise_error

      expect(Vye::UserInfo.where(bdn_clone_active: [nil, false]).count).to eq(10)
      expect(Vye::UserInfo.where(bdn_clone_active: true).count).to eq(5)
    end
  end
end
