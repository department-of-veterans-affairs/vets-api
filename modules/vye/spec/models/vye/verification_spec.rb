# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::Verification, type: :model do
  describe 'create' do
    let!(:user_info) { create(:vye_user_info) }
    let!(:award) { create(:vye_award, user_info:) }

    it 'creates a record' do
      expect do
        attributes = FactoryBot.attributes_for(:vye_verification, user_info:, award_id: award.id)
        Vye::Verification.create!(attributes)
      end.to change(Vye::Verification, :count).by(1)
    end
  end
end
