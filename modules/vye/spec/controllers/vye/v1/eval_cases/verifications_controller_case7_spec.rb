# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  # happy path conditions
  # 1 date last certified is before last day of previous month or date last certified is blank
  #   the 2nd part of the guard clause in condition 1 can never be true due to condition 5
  # 2 award indicator is future
  # 3 the certificate is not open (indicator is current and award end date is blank)
  # 4 award begin date <= last day of prior month
  # 5 the date last certified is not blank (nil)
  # 6 last day of prior month < award end date
  describe 'eval_case7' do
    subject { described_class.new }

    let(:payment_date) { Date.new(2025, 2, 14) }
    let(:award_begin_date) { Date.new(2025, 1, 15) }
    let(:award_end_date) { Date.new(2025, 2, 15) }
    let(:last_day_of_prior_month) { Date.new(2025, 1, 31) }

    describe 'happy path(s)' do
      context 'all conditions are met' do
        let(:date_last_certified) { Date.new(2025, 1, 1) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification for case7' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case7').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to eq(award_begin_date)
          expect(pending_verification.act_end).to eq(last_day_of_prior_month)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(last_day_of_prior_month)
          expect(pending_verification.trace).to eq('case7')
        end
      end
    end

    # no case7 pending verifications will be created in any of these scenarios
    describe 'unhappy paths' do
      context 'when date last certified is >= last day of previous month' do
        let(:date_last_certified) { Date.new(2025, 1, 31) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 1st check' do
          expect_contra(Date.new(2025, 2, 15), 'case7')
        end
      end

      context 'when award indicator is not future' do
        let(:date_last_certified) { Date.new(2025, 1, 1) }

        # create past award, current awards can meet earlier cases which doesn't prove the guard condition failed
        before { setup_past_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 2nd check' do
          expect_contra(Date.new(2025, 2, 15), 'case7')
        end
      end

      # This is a problem. If it was current, it would have been flagged as an open cert first
      # and no more processing would have occurred. In this case, it's future which at some
      # point in the future will become current at which point it would get flagged as an
      # open cert. The way it works now, it falls into case 8 and creates a pending verification
      # with no act_end date which blows up the code. The open cert rules should not distinguish
      # between current an future awards imo. This can also be fixed by modifying guard condition 6
      # on eval_case8 to return if award_end_date is nil.
      context 'when award end date is blank (nil)', skip: 'see above comment' do
        let(:date_last_certified) { Date.new(2025, 1, 1) }

        before { setup_future_award(award_begin_date:, award_end_date: nil, payment_date:) }

        it 'returns from the 3rd check' do
          expect_contra(Date.new(2025, 2, 15), 'case7')
        end
      end

      context 'when the last day of the prior month < award begin date' do
        let(:date_last_certified) { Date.new(2025, 1, 1) }
        let(:award_begin_date) { Date.new(2025, 2, 1) }
        let(:award_end_date) { Date.new(2025, 2, 28) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 4th check' do
          expect_contra(Date.new(2025, 2, 15), 'case7')
        end
      end

      # eval_case6 picks this up so we never get here. This is just a placeholder
      # context 'when date last certified is blank' do
      # end

      context 'last day of prior month >= award end date' do
        let(:date_last_certified) { Date.new(2025, 1, 1) }
        let(:award_end_date) { Date.new(2025, 1, 31) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 6th check' do
          expect_contra(Date.new(2025, 2, 15), 'case7')
        end
      end
    end
  end
end
