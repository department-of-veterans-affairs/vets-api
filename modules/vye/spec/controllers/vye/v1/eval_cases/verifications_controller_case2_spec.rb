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
  # 4 award end date != date last certified
  # 5 award end date >= current date (run date)
  # 6 award begin date <= last day of prior month < award end date

  describe 'eval_case2' do
    subject { described_class.new }

    let(:payment_date) { Date.new(2025, 2, 14) }
    let(:award_begin_date) { Date.new(2025, 1, 30) }
    let(:award_end_date) { Date.new(2025, 2, 25) }
    let(:last_day_of_prior_month) { Date.new(2025, 1, 31) }

    describe 'happy path(s)' do
      context 'when date last certified is before last day of previous month' do
        let(:date_last_certified) { Date.new(2025, 1, 5) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case2').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to eq(date_last_certified)
          expect(pending_verification.act_end).to eq(last_day_of_prior_month)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(last_day_of_prior_month)
          expect(pending_verification.trace).to eq('case2')
        end
      end

      context 'when date last certified is blank (nil)' do
        let(:date_last_certified) { nil }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification with a nil act_begin' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case2').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to be_nil
          expect(pending_verification.act_end).to eq(last_day_of_prior_month)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(last_day_of_prior_month)
          expect(pending_verification.trace).to eq('case2')
        end
      end
    end

    # no case2 pending verifications will be created in any of these scenarios
    describe 'unhappy paths' do
      context 'when date last certified >= last day of previous month' do
        let(:date_last_certified) { Date.new(2025, 1, 31) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case2')
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
          expect_contra(Date.new(2025, 2, 15), 'case2')
        end
      end

      # when award end date is blank (nil)
      # This unappy path shouldn't happen because it's flagged as an open cert first
      # the open cert rules are:
      # 1 date last certified < last day of prior month or date last certified is blank
      # 2 the award indicator is current
      # 3 the award_end_date is blank
      # These are also the first 3 checks for case2.

      context 'when award begin date = date last certified' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_begin_date) { date_last_certified }
        let(:award_end_date) { date_last_certified }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 4th check' do
          expect_contra(Date.new(2025, 2, 15), 'case2')
        end
      end

      # when award end date < run date (condition 5)
      # this unhappy path shouldn't happen because it meets the criteria for a case2 pending verification
      # the only difference between case2 and case2 is that case2 has an award end date >= run date and
      # case2 has an award end date < run date

      # Happy path is
      # award begin date <= last day of prior month < award end date
      # Unhappy paths that trigger this failure condition are
      # award begin date > last day of prior month
      # or
      # last day of prior month >= award end date
      context 'the award begin date > last day of prior month' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }
        let(:award_begin_date) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 3, 1) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 6th check because of the award begin date' do
          expect_contra(Date.new(2025, 2, 15), 'case2')
        end
      end

      # it won't hit this context because case_1b is handled first and creates a pending verification
      # context 'the last day of the prior month >= award end date' do
      # end
    end
  end
end
