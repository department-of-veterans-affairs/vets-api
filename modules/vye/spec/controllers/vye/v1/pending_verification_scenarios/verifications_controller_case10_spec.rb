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
  #####################################################
  # happy path                      [act_begin, act_end]
  # ldpm <= dlc	<	abd	< aed <= rd   [abd, aed - 1 day]
  # 3/31    3/31  4/2   4/3    4/15  4/2  4/2
  # 3/31    4/1   4/2   4/14   4/15  4/2  4/14
  #####################################################
  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case10' do
    subject { described_class.new }

    let(:run_date) { Date.new(2025, 4, 15) }
    let(:last_day_of_prior_month) { Date.new(2025, 3, 31) }
    let(:payment_date) { Date.new(2025, 3, 31) }
    let(:date_last_certified) { Date.new(2025, 3, 31) }
    let(:award_begin_date) { Date.new(2025, 4, 2) }

    describe 'happy path(s)' do
      context 'case10 happy path 1' do
        let(:award_end_date) { Date.new(2025, 4, 3) }
        let(:aed_minus1) { Date.new(2025, 4, 2) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case10 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case10')
        end
      end

      context 'case10 happy path 2' do
        let(:date_last_certified) { Date.new(2025, 4, 1) }
        let(:award_end_date) { Date.new(2025, 4, 15) }
        let(:aed_minus1) { Date.new(2025, 4, 14) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'creates a case10 pending verification' do
          run_the_happy_path(run_date, award_begin_date, aed_minus1, aed_minus1, 'case10')
        end
      end
    end

    # no case10 pending verifications will be created in any of these scenarios
    describe 'contra paths' do
      context 'when dlc < ldpm' do
        let(:date_last_certified) { Date.new(2025, 3, 30) }
        let(:award_end_date) { Date.new(2025, 4, 15) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case10 pending verification' do expect_contra(run_date, 'case10') end
      end

      # you never get this far because case4 evaluates to true first
      # context 'when abd <= dlc' do
      # end

      context 'when rd < aed' do
        let(:award_end_date) { Date.new(2025, 4, 16) }

        before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

        it 'does not create a case10 pending verification' do expect_contra(run_date, 'case10') end
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
