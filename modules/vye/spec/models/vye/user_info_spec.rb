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

  describe 'calculating enrollments' do
    describe 'EOM case' do
      let(:cur_award_ind) { Vye::Award.cur_award_inds[:future] }
      let(:now) { Time.parse('2024-03-31T12:00:00-00:00') }
      let(:date_last_certified) { Date.new(2024, 2, 15) }
      let(:last_day_of_previous_month) { Date.new(2024, 2, 29) }
      let(:award_begin_date) { Date.new(2024, 3, 30) }
      let(:today) { Date.new(2024, 3, 31) }
      let(:award_end_date) { Date.new(2024, 4, 1) }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case_eom')
      end
    end

    describe 'case 1a' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-05-15') }
      let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
      let(:award_begin_date) { Date.parse('2024-07-01') }
      let(:award_end_date) { Date.parse('2024-07-01') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case1a')
      end
    end

    describe 'case 1b' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-05-15') }
      let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
      let(:award_begin_date) { Date.parse('2024-06-01') }
      let(:award_end_date) { Date.parse('2024-06-29') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case1b')
      end
    end

    describe 'case 2' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-05-15') }
      let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
      let(:award_begin_date) { Date.parse('2024-06-01') }
      let(:award_end_date) { Date.parse('2024-07-20') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case2')
      end
    end

    describe 'case 3' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-05-15') }
      let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
      let(:award_begin_date) { Date.parse('2024-07-01') }
      let(:award_end_date) { Date.parse('2024-07-20') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case3')
      end
    end

    describe 'case 4' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-04-15') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award1) do
        cur_award_ind = Vye::Award.cur_award_inds[:current]
        award_begin_date = Date.parse('2024-05-01')
        award_end_date = nil
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:)
      end
      let!(:award2) do
        cur_award_ind = Vye::Award.cur_award_inds[:future]
        award_begin_date = Date.parse('2024-07-01')
        award_end_date = Date.parse('2024-07-31')
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:)
      end

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case4')
      end
    end

    describe 'case 5' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-05-15') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award1) do
        cur_award_ind = Vye::Award.cur_award_inds[:current]
        award_begin_date = Date.parse('2024-05-01')
        award_end_date = nil
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:)
      end
      let!(:award2) do
        cur_award_ind = Vye::Award.cur_award_inds[:future]
        award_begin_date = Date.parse('2024-06-01')
        award_end_date = Date.parse('2024-08-01')
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:)
      end

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.find { |v| v.award_id = award2.id }.trace).to eq('case5')
      end
    end

    describe 'case 6' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { nil }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) do
        cur_award_ind = Vye::Award.cur_award_inds[:future]
        award_begin_date = Date.parse('2024-06-01')
        award_end_date = Date.parse('2024-07-15')
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:)
      end

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case6')
      end
    end

    describe 'case 7' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-05-15') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) do
        cur_award_ind = Vye::Award.cur_award_inds[:future]
        award_begin_date = Date.parse('2024-06-01')
        award_end_date = Date.parse('2024-07-15')
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:)
      end

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case7')
      end
    end

    describe 'case 8' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-05-15') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) do
        cur_award_ind = Vye::Award.cur_award_inds[:future]
        award_begin_date = Date.parse('2024-05-01')
        award_end_date = Date.parse('2024-06-30')
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:)
      end

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case8')
      end
    end

    describe 'case 9' do
      let(:now) { Time.parse('2024-07-19T12:00:00-00:00') }
      let(:date_last_certified) { Date.parse('2024-06-30') }
      let!(:user_info) { create(:vye_user_info, date_last_certified:) }
      let!(:award) do
        cur_award_ind = Vye::Award.cur_award_inds[:future]
        award_begin_date = Date.parse('2024-07-01')
        award_end_date = Date.parse('2024-07-01')
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:)
      end

      before do
        Timecop.travel(now)
      end

      after do
        Timecop.return
      end

      it 'shows an enrollment' do
        pending_verifications = user_info.pending_verifications

        expect(pending_verifications.length).to eq(1)
        expect(pending_verifications.first.trace).to eq('case9')
      end
    end

    describe '#td_number' do
      let(:mpi_profile) { double('MpiProfile') }
      let!(:user_info) do
        create(:vye_user_info_td_number)
      end

      before do
        allow(user_info).to receive(:mpi_profile).and_return(mpi_profile)
        allow(mpi_profile).to receive(:ssn).and_return('123456789')
      end

      it 'moves the last two digits of the ssn to the front' do
        expect(user_info.td_number).to eq('891234567')
      end
    end
  end
end
