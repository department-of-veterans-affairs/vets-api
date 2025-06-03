# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'
  before do
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

  #################################
  # glossary
  #################################
  # award begin date (abd)
  # date last certified (dlc)
  # award end date (aed)
  # last day of prior month (ldpm)
  # run date (rd)
  #########################################################
  # happy path                     [act_begin, act_end]
  # dlc < abd < ldpm <= aed <= rd  [abd,       aed - 1 day] or
  # dlc < abd <= ldpm < aed <= rd  [abd,       aed - 1 day]
  # 3/1   3/30   3/31   3/31   4/15 3/30       3/31
  # 3/1   3/2    3/31   4/1    4/15 3/2        3/31
  # 3/1   3/31   3/31   4/1    4/15 3/31       3/31
  # 3/1   3/31   3/31   4/2    4/15 3/31       4/1
  # 3/1   3/31   3/31   4/15   4/15 3/31       4/14
  #########################################################
  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case6' do
    subject { described_class.new }

    let(:run_date) { Date.new(2025, 4, 15) }
    let(:last_day_of_prior_month) { Date.new(2025, 3, 31) }
    let(:payment_date) { Date.new(2025, 3, 1) }
    let(:date_last_certified) { Date.new(2025, 3, 1) }

    describe 'happy path(s)' do
      context 'case6 happy path 1' do
        let(:award_begin_date) { Date.new(2025, 3, 30) }
        let(:award_end_date) { Date.new(2025, 3, 31) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case6 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case6')
        end
      end

      context 'case6 happy path 2' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 4, 1) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case6 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case6')
        end
      end

      context 'case6 happy path 3' do
        let(:award_begin_date) { Date.new(2025, 3, 31) }
        let(:award_end_date) { Date.new(2025, 4, 1) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case6 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case6')
        end
      end

      context 'case6 happy path 4' do
        let(:award_begin_date) { Date.new(2025, 3, 31) }
        let(:award_end_date) { Date.new(2025, 4, 2) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case6 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case6')
        end
      end

      context 'case6 happy path 5' do
        let(:award_begin_date) { Date.new(2025, 3, 31) }
        let(:award_end_date) { Date.new(2025, 4, 15) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case6 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case6')
        end
      end
    end

    # no case6 pending verifications will be created in any of these scenarios
    describe 'contra paths' do
      context 'when abd <= dlc' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 2) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case6 pending verification' do expect_contra(run_date, 'case6') end
      end

      context 'when ldpm < abd' do
        let(:award_begin_date) { Date.new(2025, 4, 1) }
        let(:award_end_date) { Date.new(2025, 4, 2) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case6 pending verification' do expect_contra(run_date, 'case6') end
      end

      context 'when aed < ldpm' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 3, 30) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case6 pending verification' do expect_contra(run_date, 'case6') end
      end

      context 'when rd < aed' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 4, 16) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case6 pending verification' do expect_contra(run_date, 'case6') end
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
