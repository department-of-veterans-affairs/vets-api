# frozen_string_literal: true
require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  #################################
  # glossary
  #################################
  # award begin date (abd)
  # date last certified (dlc)
  # award end date (aed)
  # last day of prior month (ldpm)
  # run date (rd)
  ########################################################
  # happy path                        [act_begin, act_end]
  # ldpm <	abd	<=	dlc < aed	<= rd   [dlc, aed - 1 day]
  # 3/31    4/1     4/1   4/3    4/15  4/1  4/2
  # 3/31    4/1     4/2   4/3    4/15  4/2  4/2
  # 3/31    4/1     4/2   4/15   4/15  4/2  4/14
  ########################################################
  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case9' do
    subject { described_class.new }

    let(:run_date) { Date.new(2025, 4, 15) }
    let(:last_day_of_prior_month) { Date.new(2025, 3, 31) }
    let(:payment_date) { Date.new(2025, 4, 2) }
    let(:date_last_certified) { Date.new(2025, 4, 2) }
    let(:award_begin_date) { Date.new(2025, 4, 1) }
    let(:award_end_date) { Date.new(2025, 4, 3) }
    let(:aed_minus1) { Date.new(2025, 4, 2) }

    describe 'happy path(s)' do
      context 'case9 happy path 1' do
        let(:date_last_certified) { Date.new(2025, 4, 1) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case9 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case9')
        end
      end

      context 'case9 happy path 2' do
        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case9 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case9')
        end
      end

      context 'case9 happy path 3' do
        let(:award_end_date) { Date.new(2025, 4, 15) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case9 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case9')
        end
      end
    end

    # no case9 pending verifications will be created in any of these scenarios
    describe 'contra paths' do
      context 'when abd <= ldpm' do
        let(:award_begin_date) { Date.new(2025, 3, 31) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case9 pending verification' do expect_contra(run_date, 'case9') end
      end

      context 'when dlc < abd' do
        let(:award_begin_date) { Date.new(2025, 4, 3) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case9 pending verification' do expect_contra(run_date, 'case9') end
      end

      context 'when aed <= dlc' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 4, 2) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case9 pending verification' do expect_contra(run_date, 'case9') end
      end

      context 'when rd < aed' do
        let(:award_end_date) { Date.new(2025, 4, 16) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case9 pending verification' do expect_contra(run_date, 'case9') end
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
