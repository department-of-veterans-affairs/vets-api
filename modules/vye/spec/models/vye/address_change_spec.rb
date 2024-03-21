# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::AddressChange, type: :model do
  let(:user_info) { FactoryBot.create(:vye_user_info) }

  describe 'create' do
    let(:attributes) { FactoryBot.attributes_for(:vye_address_change, user_info:) }

    it 'creates a record' do
      expect do
        described_class.create!(attributes)
      end.to change(described_class, :count).by(1)
    end
  end

  describe 'creates a report' do
    let!(:address_changes) { FactoryBot.create(:vye_address_change, user_info:) }

    it 'shows todays verifications' do
      expect(described_class.todays_records.length).to eq(1)
    end

    it 'shows todays verification report' do
      expect(described_class.todays_report).to be_a(String)
    end
  end
end
