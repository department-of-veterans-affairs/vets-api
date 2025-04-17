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
  #######################################################
  # happy path                    [act_begin, act_end]
  # dlc < abd < aed < ldpm < rd   [abd,       aed - 1day]
  # 3/1   3/2   3/3   3/31   4/15  3/2        3/2
  # 3/1   3/2   3/30  3/31   4/15  3/2        3/29
  #######################################################
  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case5' do
    subject { described_class.new }

    let(:run_date) { Date.new(2025, 4, 15) }
    let(:last_day_of_prior_month) { Date.new(2025, 3, 31) }
    let(:payment_date) { Date.new(2025, 3, 1) }
    let(:date_last_certified) { Date.new(2025, 3, 1) }

    describe 'happy path(s)' do
      context 'case5 happy path 1' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 3, 3) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case5 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case5')
        end
      end

      context 'case5 happy path 2' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 3, 30) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case5 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case5')
        end
      end
    end

    # no case5 pending verifications will be created in any of these scenarios
    describe 'contra paths' do
      context 'when abd <= dlc' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 3, 30) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case5 pending verification' do expect_contra(run_date, 'case5') end
      end

      context 'when ldpm <= aed' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 3, 31) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case5 pending verification' do expect_contra(run_date, 'case5') end
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
