# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::DirectDepositChange, type: :model do
  describe 'create' do
    let(:user_info) { FactoryBot.create(:vye_user_info) }

    it 'creates a record' do
      expect do
        attributes = FactoryBot.attributes_for(:vye_direct_deposit_change)
        user_info.direct_deposit_changes.create!(attributes)
      end.to change(Vye::DirectDepositChange, :count).by(1)
    end
  end
end
