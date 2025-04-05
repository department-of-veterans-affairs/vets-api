# frozen_string_literal: true
require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  let!(:current_user) { create(:user, :accountable) }

  before do
    sign_in_as(current_user)
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(Vye::V1::VerificationsController).to receive(:authorize).and_return(true)
  end

  describe '#create' do
    subject { described_class.new }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:future] }
    let(:now) { Time.parse('2024-03-31T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2024, 2, 15) }
    let(:award_begin_date) { Date.new(2024, 3, 30) }
    let(:award_end_date) { Date.new(2024, 4, 1) }
    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    let!(:award) { create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:) }
    let!(:award2) { create(:vye_award, user_info:, cur_award_ind:) }
    let(:award_ids) { user_info.awards.pluck(:id) }
    let(:params) { { award_ids: } }

    # rubocop:disable RSpec/SubjectStub
    before do
      allow(subject).to receive_messages(
        params:,
        current_user:,
        head: :no_content
      )
      subject.send(:load_user_info)
    end

    describe 'cert_through_date calculation' do
      let!(:verification1) { create(:vye_verification, act_end: Date.new(2024, 4, 1), award: award) }
      let!(:verification2) { create(:vye_verification, act_end: Date.new(2024, 5, 1), award: award2) }

      before do
        allow(subject).to receive(:pending_verifications).and_return([verification1, verification2])
      end

      it 'returns verification-specific act_end when current date is on or after that verification act_end' do
        Timecop.freeze(Date.new(2024, 4, 1)) do
          expect(subject.send(:cert_through_date, verification1).to_date).to eq(verification1.act_end.to_date)
          expect(subject.send(:cert_through_date, verification2).to_date).to eq(Date.new(2024, 3, 31))
        end
      end

      it 'returns end of current month when on last day of month' do
        Timecop.freeze(Date.new(2024, 3, 31)) do
          expect(subject.send(:cert_through_date, verification1).to_date).to eq(Date.new(2024, 3, 31))
          expect(subject.send(:cert_through_date, verification2).to_date).to eq(Date.new(2024, 3, 31))
        end
      end

      it 'returns end of previous month for mid-month dates' do
        Timecop.freeze(Date.new(2024, 3, 15)) do
          expect(subject.send(:cert_through_date, verification1).to_date).to eq(Date.new(2024, 2, 29))
          expect(subject.send(:cert_through_date, verification2).to_date).to eq(Date.new(2024, 2, 29))
        end
      end
    end
  end

  # rubocop:disable Naming/VariableNumber
  describe 'shay production bug 1' do
    subject { described_class.new }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
    let(:now) { Time.parse('2025-02-05T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2024, 10, 1) }

    let(:award_begin_date_1) { Date.new(2024, 3, 9) }
    let(:award_begin_date_2) { Date.new(2024, 3, 11) }
    let(:award_begin_date_3) { Date.new(2024, 8, 19) }
    let(:award_begin_date_4) { Date.new(2024, 10, 1) }
    let(:award_begin_date_5) { Date.new(2024, 10, 12) }

    let(:award_end_date_1) { Date.new(2024, 5, 11) }
    let(:award_end_date_2) { Date.new(2024, 12, 14) }
    let(:award_end_date_3) { Date.new(9999, 12, 31) }

    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    # let!(:award1) { create(:vye_award, user_info:, award_begin_date: award_begin_date_1, award_end_date: award_end_date_3, cur_award_ind:) }
    let!(:award2) { create(:vye_award, user_info:, award_begin_date: award_begin_date_2, award_end_date: award_end_date_1, cur_award_ind:) }
    # let!(:award3) { create(:vye_award, user_info:, award_begin_date: award_begin_date_3, award_end_date: award_end_date_3, cur_award_ind:) }
    # let!(:award4) { create(:vye_award, user_info:, award_begin_date: award_begin_date_4, award_end_date: award_end_date_3, cur_award_ind:) }
    let!(:award5) { create(:vye_award, user_info:, award_begin_date: award_begin_date_5, award_end_date: award_end_date_2, cur_award_ind:) }

    let(:award_ids) { user_info.awards.pluck(:id) }
    let(:params) { { award_ids: } }

    before do
      allow(subject).to receive_messages(params:, current_user:, head: :no_content)
      subject.send(:load_user_info)
    end

    describe 'cert through date calculation bug 1' do
      it 'calculates the transact date to be 2024-12-13' do
        Timecop.freeze(Date.new(2025, 2, 5)) do
          subject.create
        end

        expect(Vye::Verification.count).to eq(5)
        expect(Vye::Award.count).to eq(5)
      end
    end
  end

  describe 'shay production bug 2' do
    subject { described_class.new }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
    let(:now) { Time.parse('2025-01-29T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2024, 12, 1) }

    let(:award_begin_date_1) { Date.new(2024, 10, 5) }
    let(:award_begin_date_2) { Date.new(2024, 10, 9) }
    let(:award_begin_date_3) { Date.new(2024, 12, 7) }
    let(:award_begin_date_4) { Date.new(2025, 1, 8) }
    let(:award_begin_date_5) { Date.new(2025, 3, 5) }

    let(:award_end_date_1) { Date.new(2024, 12, 11) }
    let(:award_end_date_2) { Date.new(2025, 3, 1) }
    let(:award_end_date_3) { Date.new(2025, 5, 3) }

    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    let!(:award1) { create(:vye_award, user_info:, award_begin_date: award_begin_date_1, award_end_date: nil, cur_award_ind:) }
    let!(:award2) { create(:vye_award, user_info:, award_begin_date: award_begin_date_2, award_end_date: nil, cur_award_ind:) }
    let!(:award3) { create(:vye_award, user_info:, award_begin_date: award_begin_date_3, award_end_date: award_end_date_1, cur_award_ind:) }
    let!(:award4) { create(:vye_award, user_info:, award_begin_date: award_begin_date_4, award_end_date: award_end_date_2, cur_award_ind:) }
    let!(:award5) { create(:vye_award, user_info:, award_begin_date: award_begin_date_5, award_end_date: award_end_date_3, cur_award_ind:) }

    let(:award_ids) { user_info.awards.pluck(:id) }
    let(:params) { { award_ids: } }

    before do
      allow(subject).to receive_messages(params:, current_user:, head: :no_content)
      subject.send(:load_user_info)
    end

    describe 'cert through date calculation bug 2' do
      it 'calculates the transact date to be 2024-12-13' do
        Timecop.freeze(Date.new(2025, 1, 29)) do
          subject.create
        end

        expect(Vye::Verification.count).to eq(5)
        expect(Vye::Award.count).to eq(5)
      end
    end
  end

  describe 'shay production bug 3' do
    subject { described_class.new }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
    let(:now) { Time.parse('2025-01-01T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2024, 12, 1) }

    let(:award_begin_date_1) { Date.new(2024, 1, 16) }
    let(:award_begin_date_2) { Date.new(2024, 5, 30) }
    let(:award_begin_date_3) { Date.new(2024, 7, 1) }
    let(:award_begin_date_4) { Date.new(2024, 8, 26) }
    let(:award_begin_date_5) { Date.new(2024, 10, 1) }

    let(:award_end_date_1) { Date.new(2024, 5, 9) }
    let(:award_end_date_2) { Date.new(2024, 8, 2) }
    let(:award_end_date_3) { Date.new(2024, 12, 14) }

    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    let!(:award1) { create(:vye_award, user_info:, award_begin_date: award_begin_date_1, award_end_date: award_end_date_1, cur_award_ind:) }
    let!(:award2) { create(:vye_award, user_info:, award_begin_date: award_begin_date_2, cur_award_ind:) }
    let!(:award3) { create(:vye_award, user_info:, award_begin_date: award_begin_date_3, award_end_date: award_end_date_2, cur_award_ind:) }
    let!(:award4) { create(:vye_award, user_info:, award_begin_date: award_begin_date_4, cur_award_ind:) }
    let!(:award5) { create(:vye_award, user_info:, award_begin_date: award_begin_date_5, award_end_date: award_end_date_3, cur_award_ind:) }

    let(:award_ids) { user_info.awards.pluck(:id) }
    let(:params) { { award_ids: } }

    before do
      allow(subject).to receive_messages(params:, current_user:, head: :no_content)
      subject.send(:load_user_info)
    end

    describe 'cert through date calculation bug 1' do
      it 'calculates the transact date to be 2024-12-13' do
        Timecop.freeze(Date.new(2025, 1, 1)) do
          subject.create
        end

        expect(Vye::Verification.count).to eq(5)
        expect(Vye::Award.count).to eq(5)
      end
    end
  end

  describe 'shay production bug 4' do
    subject { described_class.new }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
    let(:now) { Time.parse('2025-01-01T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2024, 12, 1) }

    let(:award_begin_date_1) { Date.new(2023, 8, 21) }
    let(:award_begin_date_2) { Date.new(2023, 10, 1) }
    let(:award_begin_date_3) { Date.new(2024, 1, 15) }
    let(:award_begin_date_4) { Date.new(2024, 8, 26) }
    let(:award_begin_date_5) { Date.new(2024, 10, 1) }

    let(:award_end_date_1) { Date.new(2023, 12, 16) }
    let(:award_end_date_2) { Date.new(2024, 5, 11) }
    let(:award_end_date_3) { Date.new(2024, 12, 21) }
    let(:award_end_date_x) { Date.new(2024, 9, 30) }

    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    # let!(:award1) { create(:vye_award, user_info:, award_begin_date: award_begin_date_1, award_end_date: award_end_date_1, cur_award_ind:) }
    # let!(:award2) { create(:vye_award, user_info:, award_begin_date: award_begin_date_2, cur_award_ind:) }
    # let!(:award3) { create(:vye_award, user_info:, award_begin_date: award_begin_date_3, award_end_date: award_end_date_2, cur_award_ind:) }
    let!(:award4) { create(:vye_award, user_info:, award_begin_date: award_begin_date_4, award_end_date: award_end_date_x, cur_award_ind:) }
    let!(:award5) { create(:vye_award, user_info:, award_begin_date: award_begin_date_5, award_end_date: award_end_date_3, cur_award_ind:) }

    let(:award_ids) { user_info.awards.pluck(:id) }
    let(:params) { { award_ids: } }

    before do
      allow(subject).to receive_messages(params:, current_user:, head: :no_content)
      subject.send(:load_user_info)
    end

    describe 'cert through date calculation bug 4' do
      it 'calculates the transact date to be 2024-12-20' do
        Timecop.freeze(Date.new(2025, 3, 5)) do
          subject.create
        end

        expect(Vye::Verification.count).to eq(2)
        expect(Vye::Award.count).to eq(2)
      end
    end
  end

  describe 'shay production bug 5' do
    subject { described_class.new }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
    let(:now) { Time.parse('2025-03-10T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2025, 2, 1) }

    let(:award_begin_date_1) { Date.new(2024, 12, 9) }
    let(:award_begin_date_2) { Date.new(2025, 2, 18) }
    let(:award_begin_date_3) { Date.new(2025, 2, 24) }
    let(:award_begin_date_4) { Date.new(2025, 3, 3) }
    let(:award_begin_date_5) { Date.new(2025, 3, 10) }

    let(:award_end_date_1) { Date.new(2025, 2, 14) }
    let(:award_end_date_2) { Date.new(2025, 2, 21) }
    let(:award_end_date_3) { Date.new(2025, 2, 28) }
    let(:award_end_date_4) { Date.new(2025, 3, 7) }
    let(:award_end_date_5) { Date.new(2025, 5, 9) }

    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    # let!(:award1) { create(:vye_award, user_info:, award_begin_date: award_begin_date_1, award_end_date: award_end_date_1, cur_award_ind:) }
    let!(:award2) { create(:vye_award, user_info:, award_begin_date: award_begin_date_2, award_end_date: award_end_date_2,cur_award_ind:) }
    let!(:award3) { create(:vye_award, user_info:, award_begin_date: award_begin_date_3, award_end_date: award_end_date_3, cur_award_ind:) }
    let!(:award4) { create(:vye_award, user_info:, award_begin_date: award_begin_date_4, award_end_date: award_end_date_4, cur_award_ind:) }
    let!(:award5) { create(:vye_award, user_info:, award_begin_date: award_begin_date_5, award_end_date: award_end_date_5, cur_award_ind:) }

    let(:award_ids) { user_info.awards.pluck(:id) }
    let(:params) { { award_ids: } }

    before do
      allow(subject).to receive_messages(params:, current_user:, head: :no_content)
      subject.send(:load_user_info)
    end

    describe 'cert through date calculation bug 4' do
      it 'calculates the transact date to be 2024-12-20' do
        Timecop.freeze(Date.new(2025, 3, 10)) do
          subject.create
        end

        expect(Vye::Verification.count).to eq(2)
        expect(Vye::Award.count).to eq(2)
      end
    end
  end

  describe 'shay production bug 6' do
    subject { described_class.new }

    let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }
    let(:now) { Time.parse('2025-03-24T12:00:00-00:00') }
    let(:date_last_certified) { Date.new(2025, 2, 27) }

    let(:award_begin_date_1) { Date.new(2024, 11, 19) }
    let(:award_begin_date_2) { Date.new(2025, 1, 7) }
    let(:award_begin_date_3) { Date.new(2025, 2, 11) }
    # let(:award_begin_date_4) { Date.new(2025, 3, 25) }

    let(:award_end_date_1) { Date.new(2024, 12, 24) }
    let(:award_end_date_2) { Date.new(2025, 2, 11) }
    let(:award_end_date_3) { Date.new(2025, 3, 18) }
    # let(:award_end_date_4) { Date.new(2025, 4, 29) }

    let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
    let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
    let!(:award1) { create(:vye_award, user_info:, award_begin_date: award_begin_date_1, award_end_date: award_end_date_1, cur_award_ind: 'P') }
    let!(:award2) { create(:vye_award, user_info:, award_begin_date: award_begin_date_2, award_end_date: award_end_date_2,cur_award_ind: 'C') }
    let!(:award3) { create(:vye_award, user_info:, award_begin_date: award_begin_date_3, award_end_date: award_end_date_3, cur_award_ind: 'C') }
    # let!(:award4) { create(:vye_award, user_info:, award_begin_date: award_begin_date_4, award_end_date: award_end_date_4, cur_award_ind:) }

    let(:award_ids) { user_info.awards.pluck(:id) }
    let(:params) { { award_ids: } }

    before do
      allow(subject).to receive_messages(params:, current_user:, head: :no_content)
      subject.send(:load_user_info)
    end

    describe 'cert through date calculation bug 4' do
      it 'calculates the transact date to be 2024-12-20' do
        Timecop.freeze(Date.new(2025, 3, 24)) do
          subject.create
        end

        expect(Vye::Verification.count).to eq(2)
        expect(Vye::Award.count).to eq(2)
      end
    end
  end
  # rubocop:enable Naming/VariableNumber
  # rubocop:enable RSpec/SubjectStub
end
