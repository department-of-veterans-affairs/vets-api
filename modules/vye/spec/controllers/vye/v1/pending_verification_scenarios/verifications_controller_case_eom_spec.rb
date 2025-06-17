# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'
  before do
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

  # rubocop:disable RSpec/NoExpectationExample
  describe 'eval_case_eom' do
    subject { described_class.new }

    let(:date_last_certified) { Date.new(2025, 3, 1) }
    let(:payment_date) { Date.new(2025, 3, 1) }
    let(:run_date) { Date.new(2025, 3, 31) }
    let(:rd_minus1) { Date.new(2025, 3, 30) }

    # there are two guard conditions for happy path end of month
    # 1) today is the end of the month
    # 2) award begin date <= today <= award end date
    # 3) date last certified is before today. It will never be future and we don't certify twice in one day?

    # check expections checks the pending verification for act_begin, act_end, transact date and trace

    describe 'eom happy path 1, dlc < abd < eom < aed' do
      let(:award_begin_date) { Date.new(2025, 3, 2) }
      let(:award_end_date) { Date.new(2025, 4, 1) }

      it 'creates a pending verification with a award begin date for act_begin and today for act_end' do
        run_the_happy_path(run_date, award_begin_date, run_date, run_date, 'case_eom')
      end
    end

    describe 'eom happy path 2, dlc < abd < eom = aed' do
      let(:award_begin_date) { Date.new(2025, 3, 2) }
      let(:award_end_date) { Date.new(2025, 3, 31) }

      it 'creates a pending verification with a award begin date for act_begin and today for act_end' do
        run_the_happy_path(run_date, award_begin_date, rd_minus1, rd_minus1, 'case_eom')
      end
    end

    # TODO: confirm w/Shay regarding activity dates
    describe 'eom happy path 3, dlc < abd = eom < aed' do
      let(:award_begin_date) { Date.new(2025, 3, 31) }
      let(:award_end_date) { Date.new(2025, 4, 2) }

      it 'creates a pending verification with a award begin date for act_begin and today for act_end' do
        run_the_happy_path(run_date, award_begin_date, run_date, run_date, 'case_eom')
      end
    end

    describe 'eom happy path 4, dlc = abd < eom < aed' do
      let(:award_begin_date) { Date.new(2025, 3, 1) }
      let(:award_end_date) { Date.new(2025, 4, 2) }

      it 'creates a pending verification with a award begin date for act_begin and today for act_end' do
        run_the_happy_path(run_date, award_begin_date, run_date, run_date, 'case_eom')
      end
    end

    describe 'eom happy path 5, dlc = abd < eom = aed' do
      let(:award_begin_date) { Date.new(2025, 3, 1) }
      let(:award_end_date) { Date.new(2025, 3, 31) }

      it 'creates a pending verification with a award begin date for act_begin and today for act_end' do
        run_the_happy_path(run_date, award_begin_date, rd_minus1, rd_minus1, 'case_eom')
      end
    end

    describe 'eom happy path 6, abd < dlc < eom < aed' do
      let(:award_begin_date) { Date.new(2025, 2, 28) }
      let(:award_end_date) { Date.new(2025, 4, 2) }

      it 'creates a pending verification with a award begin date for act_begin and today for act_end' do
        run_the_happy_path(run_date, date_last_certified, run_date, run_date, 'case_eom')
      end
    end

    describe 'eom happy path 7, abd < dlc < eom = aed' do
      let(:award_begin_date) { Date.new(2025, 2, 28) }
      let(:award_end_date) { Date.new(2025, 3, 31) }

      it 'creates a pending verification with a award begin date for act_begin and today for act_end' do
        run_the_happy_path(run_date, date_last_certified, rd_minus1, rd_minus1, 'case_eom')
      end
    end

    # contra paths
    describe 'contra paths' do
      describe 'eom contra 1, run date is not end of the month (eom)' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 3, 29) }
        let(:run_date) { Date.new(2025, 3, 30) }

        it 'does not create an eom pending verification' do
          expect_contra(run_date, 'eval_eom')
        end
      end

      # 2) this is a future award. It gets tossed out before we evaluate it for eom
      describe 'eom contra 2, run date is eom, run date < award begin date' do
        let(:award_begin_date) { Date.new(2025, 4, 1) }
        let(:award_end_date) { Date.new(2025, 4, 30) }

        it 'does not create an eom pending verification' do
          expect_contra(run_date, 'eval_eom')
        end
      end

      # 3) run date is the end of the month, award end date is before run date
      describe 'eom contra 3, run date is eom, award end date < run date' do
        let(:award_begin_date) { Date.new(2025, 3, 1) }
        let(:award_end_date) { Date.new(2025, 3, 30) }

        it 'does not create an eom pending verification' do
          expect_contra(run_date, 'eval_eom')
        end
      end
    end
  end
  # rubocop:enable RSpec/NoExpectationExample
end
