# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  ###########################################################
  # glossary
  ###########################################################
  # award begin date (abd)
  # date last certified (dlc)
  # award end date (aed)
  # last day of prior month (ldpm)
  # run date (rd)
  ###########################################################
  # happy path                           [act_begin, act_end]
  # abd <=  dlc  <  ldpm <  aed <=  rd   [dlc, aed - 1 day]
  # 2/28    3/1     3/31    3/31    4/15  3/1  3/30
  # 2/28    3/1     3/31    4/1     4/15  3/1  3/31
  # 2/28    3/1     3/31    4/3     4/15  3/1  4/2
  # 3/1     3/1     3/31    3/31    4/15  3/1  3/30
  # 3/1     3/1     3/31    4/3     4/15  3/1  4/2
  # 3/1     3/15    3/31    4/3     4/15  3/15 4/2
  # 3/1     3/30    3/31    4/15    4/15  3/30 4/14
  ###########################################################
  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case2' do
    subject { described_class.new }

    let(:run_date) { Date.new(2025, 4, 15) }
    let(:payment_date) { Date.new(2025, 3, 1) }
    let(:date_last_certified) { Date.new(2025, 3, 1) }

    describe 'happy path(s)' do
      context 'case2 happy path 1' do
        let(:award_begin_date) { Date.new(2025, 2, 28) }
        let(:award_end_date) { Date.new(2025, 3, 31) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case2 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case2')
        end
      end

      context 'case2 happy path 2' do
        let(:award_begin_date) { Date.new(2025, 2, 28) }
        let(:award_end_date) { Date.new(2025, 4, 1) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case2 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case2')
        end
      end

      context 'case2 happy path 3' do
        let(:award_begin_date) { Date.new(2025, 2, 28) }
        let(:award_end_date) { Date.new(2025, 4, 3) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case2 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case2')
        end
      end

      context 'case2 happy path 4' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 3, 31) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case2 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case2')
        end
      end

      context 'case2 happy path 5' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 3) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case2 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case2')
        end
      end

      context 'case2 happy path 6' do
        let(:date_last_certified)  { Date.new(2025, 3, 15) }
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 3) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case2 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case2')
        end
      end

      context 'case2 happy path 7' do
        let(:date_last_certified) { Date.new(2025, 3, 30) }
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 15) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case2 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case2')
        end
      end
    end

    # no case2 pending verifications will be created in any of these scenarios
    describe 'contra paths' do
      context 'when dlc < abd' do
        let(:date_last_certified) { Date.new(2025, 3, 1) }
        let(:payment_date) { Date.new(2025, 3, 1) }
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 4, 2) }
        let(:aed_minus1) { Date.new(2025, 4, 1) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case2 pending verification' do
          expect_contra(run_date, 'case2')
        end
      end

      context 'when ldpm <= dlc' do
        let(:date_last_certified) { Date.new(2025, 4, 1) }
        let(:payment_date) { Date.new(2025, 4, 1) }
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 2) }
        let(:aed_minus1) { Date.new(2025, 4, 1) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case2 pending verification' do
          expect_contra(run_date, 'case2')
        end
      end

      context 'when aed = ldpm' do
        let(:date_last_certified) { Date.new(2025, 3, 1) }
        let(:payment_date) { Date.new(2025, 3, 1) }
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 3, 31) }
        let(:aed_minus1) { Date.new(2025, 3, 30) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case2 pending verification' do
          expect_contra(run_date, 'case2')
        end
      end
    end

    context 'when rd < aed' do
      let(:date_last_certified) { Date.new(2025, 3, 1) }
      let(:payment_date) { Date.new(2025, 3, 1) }
      let(:award_begin_date) { Date.new(2025, 3, 2) }
      let(:award_end_date) { Date.new(2025, 4, 30) }
      let(:aed_minus1) { Date.new(2025, 4, 29) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create a case2 pending verification' do
        expect_contra(run_date, 'case2')
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
