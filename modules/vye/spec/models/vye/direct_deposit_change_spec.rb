# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::DirectDepositChange, type: :model do
  let(:user_info) { FactoryBot.create(:vye_user_info) }

  describe 'create' do
    it 'creates a record' do
      expect do
        attributes = FactoryBot.attributes_for(:vye_direct_deposit_change)
        user_info.direct_deposit_changes.create!(attributes)
      end.to change(described_class, :count).by(1)
    end
  end

  describe 'creates a report' do
    let!(:direct_deposit_changes) { FactoryBot.create(:vye_direct_deposit_change, user_info:) }

    before do
      ssn = '123456789'
      profile = double(ssn:)
      find_profile_by_identifier = double(profile:)
      service = double(find_profile_by_identifier:)
      allow(MPI::Service).to receive(:new).and_return(service)
    end

    it 'shows todays verifications' do
      expect(described_class.todays_records.length).to eq(1)
    end

    it 'shows todays verification report' do
      expect(described_class.todays_report).to be_a(String)
    end
  end
end
