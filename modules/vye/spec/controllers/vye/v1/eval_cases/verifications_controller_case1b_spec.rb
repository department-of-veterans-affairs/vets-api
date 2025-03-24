# frozen_string_literal: true
require 'rails_helper'
require 'support/controller_spec_helper'

# rubocop:disable RSpec/SubjectStub

# We really don't care about exceptions here, we're concerned with
# whether a certain type of pending verification is/isn't created
# rubocop:disable Lint/SuppressedException

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  let!(:current_user) { create(:user, :accountable) }
  let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
  let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
  let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }

  before do
    sign_in_as(current_user)
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(Vye::V1::VerificationsController).to receive(:authorize).and_return(true)
  end

  ####################################################################################
  # The only difference between these happy path conditions and case1a is condition 6.
  # In case1a the last day of the prior month is < the award end date
  # In case1b the last day of the prior month is >= the award end date
  ####################################################################################
  # happy path conditions
  # 1 date last certified is before last day of previous month or date last certified is blank
  # 2 award indicator is current
  # 3 award end date contains a value (date)
  # 4 the award end date is not the date last certified
  # 5 the award end date is < the current date (run date)
  # 6 the last day of the prior month is >= the award end date
  #     and the award begin and end dates are the same
  # In theory this should be rare because the award begin and end dates have to match

  describe 'eval_case1b' do
    subject { described_class.new }

    let(:payment_date) { Date.new(2025, 2, 14) }
    let(:award_begin_date) { Date.new(2025, 1, 31) }
    let(:award_end_date) { Date.new(2025, 1, 31) }
    let(:last_day_of_prior_month) { Date.new(2025, 1, 31) }

    describe 'happy path(s)' do
      context 'when date last certified is before last day of previous month' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case1b').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to eq(date_last_certified)
          expect(pending_verification.act_end).to eq(award_end_date - 1.day)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(award_end_date - 1.day)
          expect(pending_verification.trace).to eq('case1b')
        end
      end

      context 'when date last certified is blank (nil)' do
        let(:date_last_certified) { nil }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification with a nil act_begin' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case1b').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to be_nil
          expect(pending_verification.act_end).to eq(award_end_date - 1.day)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(award_end_date - 1.day)
          expect(pending_verification.trace).to eq('case1b')
        end
      end
    end

    # no case1b pending verifications will be created in any of these scenarios
    describe 'unhappy paths' do
      context 'when date last certified >= last day of previous month' do
        let(:date_last_certified) { Date.new(2025, 1, 31) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case1b').last
          expect(pending_verification).to be_nil
        end
      end

      context 'when award indicator is not current' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }

        # create past and future awards
        before do
          setup_past_award(award_begin_date:, award_end_date:, payment_date:)
          setup_future_award(award_begin_date:, award_end_date:, payment_date:)
        end

        it 'returns from the 2nd check' do
          begin
            Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }
          rescue Vye::V1::VerificationsController::AwardsMismatch
          end

          pending_verification = Vye::Verification.where(trace: 'case1b').last
          expect(pending_verification).to be_nil
        end
      end

      # This unappy path never happens because it gets flagged as an open cert first
      context 'when award end date is blank (nil)' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }

        before { setup_award(award_begin_date:, award_end_date: nil, payment_date:) }

        it 'returns from the 3rd check' do
          begin
            Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }
          rescue Vye::V1::VerificationsController::AwardsMismatch
          end

          pending_verification = Vye::Verification.where(trace: 'case1b').last
          expect(pending_verification).to be_nil
        end
      end

      context 'when award begin date = date last certified' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_begin_date) { date_last_certified }
        let(:award_end_date) { date_last_certified }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 4th check' do
          begin
            Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }
          rescue Vye::V1::VerificationsController::AwardsMismatch
          end

          pending_verification = Vye::Verification.where(trace: 'case1b').last
          expect(pending_verification).to be_nil
        end
      end

      context 'when award end date > run date' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_end_date) { Date.new(2025, 2, 14) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 5th check' do
          Timecop.freeze(Date.new(2025, 2, 13)) { subject.create }
          pending_verification = Vye::Verification.where(trace: 'case1b').last
          expect(pending_verification).to be_nil
        end
      end

      context 'the last day of prev month < awd end dt & the awd beg dt = awd end dt' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_begin_date) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 2, 1) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 6th check' do
          Timecop.freeze(Date.new(2025, 2, 13)) { subject.create }
          pending_verification = Vye::Verification.where(trace: 'case1b').last
          expect(pending_verification).to be_nil
        end
      end
    end

    def setup_award(award_begin_date:, award_end_date:, payment_date:)
      create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:, payment_date:)
      setup_controller
    end

    def setup_past_award(award_begin_date:, award_end_date:, payment_date:)
      create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind: 'P', payment_date:)
      setup_controller
    end

    def setup_future_award(award_begin_date:, award_end_date:, payment_date:)
      create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind: 'F', payment_date:)
      setup_controller
    end

    def setup_controller
      award_ids = user_info.awards.pluck(:id)
      params = { award_ids: }
      allow(subject).to receive_messages(params:, current_user:, head: :no_content)
      subject.send(:load_user_info)
    end
  end
end
# rubocop:enable Lint/SuppressedException
# rubocop:enable RSpec/SubjectStub
