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
  #####################################################
  # happy path                     [act_begin, act_end]
  # abd <= dlc < ldpm < rd < aed   [dlc,       ldpm]
  #####################################################
  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case3' do
    subject { described_class.new }

    let(:run_date) { Date.new(2025, 4, 3) }
    let(:last_day_of_prior_month) { Date.new(2025, 3, 31) }
    let(:payment_date) { Date.new(2025, 3, 1) }
    let(:date_last_certified) { Date.new(2025, 3, 1) }

    describe 'happy path(s)' do
      context 'when abd < dlc < ldpm < rd < aed' do
        let(:award_begin_date) { Date.new(2025, 2, 28) }
        let(:award_end_date) { Date.new(2025, 4, 5) }
        let(:aed_minus1) { Date.new(2025, 4, 4) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case3 pending verification' do
          Timecop.freeze(run_date) { subject.create }
          pv = Vye::Verification.last
          check_expectations_for(pv, date_last_certified, last_day_of_prior_month, last_day_of_prior_month, 'case3')
        end
      end

      context 'when abd = dlc < ldpm < rd < aed' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 4) }
        let(:aed_minus1) { Date.new(2025, 4, 3) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case3 pending verification' do
          Timecop.freeze(run_date) { subject.create }
          pv = Vye::Verification.last
          check_expectations_for(pv, date_last_certified, last_day_of_prior_month, last_day_of_prior_month, 'case3')
        end
      end
    end

    # no case3 pending verifications will be created in any of these scenarios
    describe 'contra paths' do
      context 'when dlc < abd' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 4, 5) }
        let(:aed_minus1) { Date.new(2025, 4, 4) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case3 pending verification' do
          expect_contra(run_date, 'case3')
        end
      end

      context 'when ldpm <= dlc' do
        let(:payment_date) { Date.new(2025, 4, 1) }
        let(:date_last_certified) { Date.new(2025, 4, 1) }
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 2) }
        let(:aed_minus1) { Date.new(2025, 4, 1) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case3 pending verification' do
          expect_contra(run_date, 'case3')
        end
      end

      context 'when aed = rd' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 3) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case3 pending verification' do
          expect_contra(run_date, 'case3')
        end
      end

      context 'when aed < rd' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 4, 2) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case3 pending verification' do
          expect_contra(run_date, 'case3')
        end
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
