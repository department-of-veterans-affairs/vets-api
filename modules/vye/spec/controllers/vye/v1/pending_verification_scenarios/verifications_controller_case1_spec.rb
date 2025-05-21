# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'
  before do
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

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
  # abd <=  dlc  <  aed <=  ldpm <  rd   [dlc, aed - 1 day]
  # examples
  # 2/28    3/1     3/30    3/31    4/5   3/1  3/29
  # 3/1     3/1     3/2     3/31    4/5   3/1  3/1
  # 3/1     3/1     3/30    3/31    4/5   3/1  3/29
  ###########################################################
  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case1' do
    subject { described_class.new }

    let(:run_date) { Date.new(2025, 4, 5) }

    describe 'happy path(s)' do
      let(:payment_date) { Date.new(2025, 3, 1) }
      let(:date_last_certified) { Date.new(2025, 3, 1) }

      context 'case1 happy path 1' do
        let(:award_begin_date) { Date.new(2025, 2, 28) }
        let(:award_end_date) { Date.new(2025, 3, 30) }
        let(:aed_minus1) { award_end_date - 1.day }

        it 'creates a case1 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case1')
        end
      end

      context 'case1 happy path 2' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 3, 2) }
        let(:aed_minus1) { award_end_date - 1.day }

        it 'creates a case1 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case1')
        end
      end

      context 'case1 happy path 3' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 3, 30) }
        let(:aed_minus1) { award_end_date - 1.day }

        it 'creates a case1 pending verification' do
          run_the_happy_path(run_date, date_last_certified, aed_minus1, aed_minus1, 'case1')
        end
      end
    end

    # no case1 pending verifications will be created in any of these scenarios
    describe 'contra paths' do
      context 'when dlc < abd' do
        let(:date_last_certified) { Date.new(2025, 3, 1) }
        let(:payment_date) { Date.new(2025, 3, 1) }
        let(:award_begin_date) { Date.new(2025, 3, 2) }
        let(:award_end_date) { Date.new(2025, 3, 30) }

        it 'does not create a case1 pending verification' do
          expect_contra(run_date, 'case1')
        end
      end

      context 'when ldpm <= aed' do
        let(:date_last_certified) { Date.new(2025, 3, 1) }
        let(:payment_date) { Date.new(2025, 3, 1) }
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 3, 31) }

        it 'does not create a case1 pending verification' do
          expect_contra(run_date, 'case1')
        end
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
