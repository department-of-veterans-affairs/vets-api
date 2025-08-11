# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::UserInfo, type: :model do
  describe 'create' do
    let!(:bdn_clone) { create(:vye_bdn_clone) }
    let!(:user_profile) { create(:vye_user_profile) }
    let(:user_info) { build(:vye_user_info, user_profile:, bdn_clone:) }

    it 'creates a record' do
      expect do
        user_info.save!
      end.to change(described_class, :count).by(1)
    end
  end
end
