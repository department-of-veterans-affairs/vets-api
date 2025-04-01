# frozen_string_literal: true
require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  # happy path conditions
  # 1 date last certified is before last day of previous month or date last certified is blank
  # 2 award indicator is current
  # 3 award end date contains a value (date)
  # 4 the award end date is not the date last certified
  # 5 the award end date is < the current date (run date)
  # 6 the last day of the prior month is before the award end date
  #     and the award begin and end dates are the same
  # In theory this should be rare because the award begin and end dates have to match

  describe 'eval_case1a' do
    subject { described_class.new }

    let(:payment_date) { Date.new(2025, 2, 14) }
    let(:award_begin_date) { Date.new(2025, 2, 14) }
    let(:award_end_date) { Date.new(2025, 2, 14) }
    let(:last_day_of_prior_month) { Date.new(2025, 1, 31) }

    describe 'happy path(s)' do
      context 'when date last certified is before last day of previous month' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case1a').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to eq(date_last_certified)
          expect(pending_verification.act_end).to eq(last_day_of_prior_month)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(last_day_of_prior_month)
          expect(pending_verification.trace).to eq('case1a')
        end
      end

      context 'when date last certified is blank (nil)' do
        let(:date_last_certified) { nil }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification with a nil act_begin' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case1a').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to be_nil
          expect(pending_verification.act_end).to eq(last_day_of_prior_month)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(last_day_of_prior_month)
          expect(pending_verification.trace).to eq('case1a')
        end
      end
    end

    # no case1a pending verifications will be created in any of these scenarios
    describe 'unhappy paths' do
      context 'when date last certified >= last day of previous month' do
        let(:date_last_certified) { Date.new(2025, 1, 31) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case1a')
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
          expect_contra(Date.new(2025, 2, 15), 'case1a')
        end
      end

      # This unappy path never happens because it gets flagged as an open cert first
      context 'when award end date is blank (nil)' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }

        before { setup_award(award_begin_date:, award_end_date: nil, payment_date:) }

        it 'returns from the 3rd check' do
          expect_contra(Date.new(2025, 2, 15), 'case1a')
        end
      end

      context 'when award begin date = date last certified' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_begin_date) { date_last_certified }
        let(:award_end_date) { date_last_certified }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 4th check' do
          expect_contra(Date.new(2025, 2, 15), 'case1a')
        end
      end

      context 'when award end date > run date' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_end_date) { Date.new(2025, 2, 14) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 5th check' do
          expect_contra(Date.new(2025, 2, 13), 'case1a')
        end
      end

      context 'the last day of previous month > award end date' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_begin_date) { Date.new(2025, 1, 29) }
        let(:award_end_date) { Date.new(2025, 1, 29) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 6th check' do
          expect_contra(Date.new(2025, 2, 13), 'case1a')
        end
      end

      context 'the last day of prev month < award end date but the award begin & end dates are different' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_begin_date) { Date.new(2025, 2, 13) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 6th check' do
          expect_contra(Date.new(2025, 2, 15), 'case1a')
        end
      end
    end
  end
end
