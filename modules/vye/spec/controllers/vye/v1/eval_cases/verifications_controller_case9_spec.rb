# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  # happy path conditions
  # 1 date last certified >= last day of previous month
  # 2 award end date < today (run date)
  # 3 the award begin date is the same as the award end date
  # Note award indicator can be any of the 3 values (P(ast)/C(current)/F(future)) for eval_case9
  describe 'eval_case9' do
    subject { described_class.new }

    let(:payment_date) { Date.new(2025, 2, 14) }
    let(:award_begin_date) { Date.new(2025, 2, 1) }
    let(:award_end_date) { Date.new(2025, 2, 1) }
    let(:last_day_of_prior_month) { Date.new(2025, 1, 31) }

    describe 'happy path(s)' do
      context 'all conditions are met - past award' do
        let(:date_last_certified) { Date.new(2025, 1, 31) }

        before { setup_past_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification for case9' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case9').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to eq(date_last_certified)
          expect(pending_verification.act_end).to eq(award_end_date - 1.day)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(award_end_date - 1.day)
          expect(pending_verification.trace).to eq('case9')
        end
      end

      context 'all conditions are met - current award' do
        let(:date_last_certified) { Date.new(2025, 1, 31) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification for case9' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case9').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to eq(date_last_certified)
          expect(pending_verification.act_end).to eq(award_end_date - 1.day)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(award_end_date - 1.day)
          expect(pending_verification.trace).to eq('case9')
        end
      end

      context 'all conditions are met - future award' do
        let(:date_last_certified) { Date.new(2025, 1, 31) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification for case9' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case9').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to eq(date_last_certified)
          expect(pending_verification.act_end).to eq(award_end_date - 1.day)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(award_end_date - 1.day)
          expect(pending_verification.trace).to eq('case9')
        end
      end
    end

    # no case9 pending verifications will be created in any of these scenarios
    describe 'unhappy paths' do
      context 'when date last certified is < last day of previous month - future award' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when date last certified is < last day of previous month - current award',
              skip: 'eval_case1a picks this up' do

        let(:date_last_certified) { Date.new(2025, 1, 30) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when date last certified is < last day of previous month - past award' do
        let(:date_last_certified) { Date.new(2025, 1, 30) }

        before { setup_past_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when date last certified is blank (nil) - future award' do
        let(:date_last_certified) { nil }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when date last certified is blank (nil) - current award',
              skip: 'eval_case1a picks this up' do
        let(:date_last_certified) { nil }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when date last certified is blank (nil) - past award' do
        let(:date_last_certified) { nil }

        before { setup_past_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when award end date >= today (run date) - current award' do
        let(:date_last_certified) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 2, 16) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 2nd check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when award end date >= today (run date) - future award' do
        let(:date_last_certified) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 2, 16) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 2nd check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when award end date >= today (run date) - past award' do
        let(:date_last_certified) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 2, 16) }

        before { setup_past_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 2nd check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when award begin and end dates are different - current award' do
        let(:date_last_certified) { Date.new(2025, 2, 1) }
        let(:award_begin_date) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 2, 14) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 3rd check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when award begin and end dates are different - future award' do
        let(:date_last_certified) { Date.new(2025, 2, 1) }
        let(:award_begin_date) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 2, 14) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 3rd check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end

      context 'when award begin and end dates are different - past award' do
        let(:date_last_certified) { Date.new(2025, 2, 1) }
        let(:award_begin_date) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 2, 14) }

        before { setup_past_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 3rd check' do
          expect_contra(Date.new(2025, 2, 15), 'case9')
        end
      end
    end
  end
end
