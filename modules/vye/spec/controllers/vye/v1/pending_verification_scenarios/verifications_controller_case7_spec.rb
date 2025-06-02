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
  ###################################################
  # happy path                   [act_begin, act_end]
  # dlc < abd <= ldpm < rd < aed [abd,       ldpm]
  # 3/1   3/2    3/31   4/2  4/3  3/2        3/31
  # 3/1   3/31   3/31   4/2  4/3  3/31       3/31
  ###################################################
  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case7' do
    subject { described_class.new }

    let(:run_date) { Date.new(2025, 4, 2) }
    let(:last_day_of_prior_month) { Date.new(2025, 3, 31) }
    let(:payment_date) { Date.new(2025, 3, 1) }
    let(:date_last_certified) { Date.new(2025, 3, 1) }

    describe 'happy path(s)' do
      context 'case7 happy path 1' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 4, 3) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case7 pending verification' do
          run_the_happy_path(run_date, award_begin_date, last_day_of_prior_month, last_day_of_prior_month, 'case7')
        end
      end

      context 'case7 happy path 2' do
        let(:award_begin_date) { Date.new(2025, 3, 31) }
        let(:award_end_date) { Date.new(2025, 4, 3) }
        let(:aed_minus1) { award_end_date - 1.day }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case7 pending verification' do
          run_the_happy_path(run_date, award_begin_date, last_day_of_prior_month, last_day_of_prior_month, 'case7')
        end
      end
    end

    # no case7 pending verifications will be created in any of these scenarios
    describe 'contra paths' do
      context 'when abd <= dlc' do
        let(:award_begin_date) { Date.new(2025, 2, 28) }
        let(:award_end_date) { Date.new(2025, 4, 3) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case7 pending verification' do expect_contra(run_date, 'case7') end
      end

      context 'when ldpm < abd' do
        let(:award_begin_date) { Date.new(2025, 4, 1) }
        let(:award_end_date) { Date.new(2025, 4, 3) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case7 pending verification' do expect_contra(run_date, 'case7') end
      end

      context 'when aed <= rd' do
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 4, 2) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case7 pending verification' do expect_contra(run_date, 'case7') end
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
