# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::Verification, type: :model do
  let(:user_info) { create(:vye_user_info) }

  describe 'create' do
    let(:attributes) { FactoryBot.attributes_for(:vye_verification, user_info:) }

    it 'creates a record' do
      expect do
        Vye::Verification.create!(attributes)
      end.to change(Vye::Verification, :count).by(1)
    end
  end

  describe 'show todays verifications' do
    let!(:verification) { FactoryBot.create(:vye_verification, user_info:) }

    before do
      ssn = '123456789'
      profile = double(ssn:)
      find_profile_by_identifier = double(profile:)
      service = double(find_profile_by_identifier:)
      allow(MPI::Service).to receive(:new).and_return(service)
    end

    it 'shows todays verifications' do
      expect(Vye::Verification.todays_verifications.length).to eq(1)
    end

    it 'shows todays verification report' do
      expect(Vye::Verification.todays_verifications_report).to be_a(String)
    end
  end
end
