# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  # happy path conditions
  # 1 date last certified is before last day of previous month or date last certified is blank
  # 2 award indicator is future
  # 3 award end date contains a value (date)
  # 4 award end date <= last day of prior month
  # 5 the date last certified is blank (nil)
  # Note: condition 1 can be removed because of condition 5
  describe 'eval_case6' do
    subject { described_class.new }

    let(:payment_date) { Date.new(2025, 2, 14) }
    let(:award_begin_date) { Date.new(2025, 1, 1) }
    let(:award_end_date) { Date.new(2025, 1, 31) }
    let(:last_day_of_prior_month) { Date.new(2025, 1, 31) }

    describe 'happy path(s)' do
      context 'all conditions are met' do
        let(:date_last_certified) { nil }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a pending verification for case6' do
          Timecop.freeze(Date.new(2025, 2, 15)) { subject.create }

          pending_verification = Vye::Verification.where(trace: 'case6').last
          expect(pending_verification).not_to be_nil
          expect(pending_verification.act_begin).to eq(award_begin_date)
          expect(pending_verification.act_end).to eq(last_day_of_prior_month)
          expect(pending_verification.payment_date).to eq(payment_date)
          expect(pending_verification.transact_date).to eq(last_day_of_prior_month)
          expect(pending_verification.trace).to eq('case6')
        end
      end
    end

    # no case6 pending verifications will be created in any of these scenarios
    # Skipping first contra case because guard condition 5 takes it's place
    describe 'unhappy paths' do
      context 'when award indicator is not future' do
        let(:date_last_certified) { nil }

        # create past award, current awards can meet earlier cases which doesn't prove the guard condition failed
        before { setup_past_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 2nd check' do
          expect_contra(Date.new(2025, 2, 15), 'case6')
        end
      end

      # when award end date is blank (nil)
      # This unappy path shouldn't happen because it's flagged as an open cert first
      # the open cert rules are:
      # 1 date last certified < last day of prior month or date last certified is blank
      # 2 the award indicator is current
      # 3 the award_end_date is blank
      # These are also the first 3 checks for case6.

      context 'when the last day of the prior month < award begin date' do
        let(:date_last_certified) { nil }
        let(:award_begin_date) { Date.new(2025, 2, 16) }
        let(:award_end_date) { Date.new(2025, 2, 28) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 4th check' do
          expect_contra(Date.new(2025, 2, 15), 'case6')
        end
      end

      context 'when date last certified is present' do
        let(:date_last_certified) { Date.new(2025, 1, 1) }

        before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'returns from the 5th check' do
          expect_contra(Date.new(2025, 2, 15), 'case6')
        end
      end
    end
  end
end
