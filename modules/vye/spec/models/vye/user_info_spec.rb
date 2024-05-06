# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::UserInfo, type: :model do
  describe 'create' do
    let(:bdn_clone) { FactoryBot.create(:vye_bdn_clone) }
    let(:user_profile) { FactoryBot.create(:vye_user_profile) }
    let(:user_info) { FactoryBot.build(:vye_user_info, user_profile:, bdn_clone:) }

    it 'creates a record' do
      expect { user_info.save! }.to change(described_class, :count).by(1)
    end
  end

  describe 'calculating enrollments' do
    describe 'EOM case' do
      let(:now) { Time.parse('2024-03-31T12:00:00-00:00') }
      let(:date_last_certified) { Date.new(2024, 2, 15) }
      let(:last_day_of_previous_month) { Date.new(2024, 2, 29) }
      let(:award_begin_date) { Date.new(2024, 3, 30) }
      let(:today) { Date.new(2024, 3, 31) }
      let(:award_end_date) { Date.new(2024, 4, 1) }
      let!(:user_info) { FactoryBot.create(:vye_user_info, date_last_certified:) }
      let!(:award) { FactoryBot.create(:vye_award, user_info:, award_begin_date:, award_end_date:) }

      it 'shows an enrollment' do
        Timecop.freeze(now) do
          user_info.pending_verifications
        end

        expect(user_info.pending_verifications.first.trace).to eq('case_eom')
      end
    end
  end
end
