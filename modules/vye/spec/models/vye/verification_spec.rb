# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::Verification, type: :model do
  describe 'create' do
    let!(:user_profile) { FactoryBot.create(:vye_user_profile) }
    let(:verification) { FactoryBot.build(:vye_verification, user_profile:) }

    it 'creates a record' do
      expect do
        verification.save!
      end.to change(Vye::Verification, :count).by(1)
    end
  end

  describe 'show todays verifications' do
    let!(:user_profile) { FactoryBot.create(:vye_user_profile) }
    let!(:user_info) { FactoryBot.create(:vye_user_info, user_profile:) }
    let!(:award) { FactoryBot.create(:vye_award, user_info:) }
    let!(:verification) { FactoryBot.create(:vye_verification, award:, user_profile:) }

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
