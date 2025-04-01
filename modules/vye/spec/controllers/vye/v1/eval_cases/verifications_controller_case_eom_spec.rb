# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  describe 'eval_case_eom' do
    subject { described_class.new }

    let(:payment_date) { Date.new(2025, 2, 15) }
    let(:award_begin_date) { Date.new(2025, 2, 9) }
    let(:award_end_date) { Date.new(2025, 3, 1) }

    # there are two guard conditions for happy path end of month
    # 1) today is the end of the month
    # 2) award begin date < today <= award end date
    #
    # If date last certified is before the award begin date and the last day of previous month
    #    act begin is award begin date otherwise act begin is date last certified

    describe 'happy path eom dlc < abd && ldpm' do
      let(:date_last_certified) { Date.new(2025, 1, 15) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'creates a pending award with a award begin date for act_begin and today for act_end' do
        Timecop.freeze(Date.new(2025, 2, 28)) { subject.create }

        run_date = Date.new(2025, 2, 28)

        # We have proved a theoretical bug in the code in that eom processing
        # can create two pending verifications. In our test scenario here,
        # eval_case_eom and case 3 both create pending verifications.
        pending_verification = Vye::Verification.first # eom pv is created first
        expect(pending_verification.act_begin.to_date).to eq(award_begin_date)
        expect(pending_verification.act_end.to_date).to eq(run_date)
        expect(pending_verification.transact_date).to eq(run_date)
        expect(pending_verification.trace).to eq('case_eom')

        # remove the next 4 lines after the bug is fixed.
        expect(Vye::Verification.count).to eq(2)
        Vye::Verification.all.find_each do |pv| # pv is pending verification
          puts "act_beg: #{pv.act_begin}, act_end: #{pv.act_end}, trans_dt: #{pv.transact_date}, trace #{pv.trace}"
        end
      end
    end

    # This case is the contra happy path to the one above
    # interestingly enough, this scenario does not create 2 pending verifications due to the conditions
    describe 'happy path eom dlc is ldpm' do
      let(:date_last_certified) { Date.new(2025, 1, 31) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'creates a pending award with a award begin date for act_begin and today for act_end' do
        Timecop.freeze(Date.new(2025, 2, 28)) { subject.create }

        run_date = Date.new(2025, 2, 28)

        pending_verification = Vye::Verification.last
        expect(pending_verification.act_begin.to_date).to eq(date_last_certified)
        expect(pending_verification.act_end.to_date).to eq(run_date)
        expect(pending_verification.transact_date).to eq(run_date)
        expect(pending_verification.trace).to eq('case_eom')
      end
    end

    describe 'run date is not the end of the month (day earlier)' do
      let(:date_last_certified) { Date.new(2025, 1, 31) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create a pending verification based on eval_case_eom' do
        expect_contra(Date.new(2025, 2, 27), 'case_eom')
      end
    end

    describe 'run date is not the end of the month (day later)' do
      let(:date_last_certified) { Date.new(2025, 1, 31) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create a pending verification based on eval_case_eom' do
        expect_contra(Date.new(2025, 3, 1), 'case_eom')
      end
    end

    # award begin date must be before eom && award end date must be >= eom
    # or eval_case_eom return without creating a pending verification
    # The following two scenarios test this
    # begin date is after eom, end date is after eom
    describe 'run date is eom, award begin date >= eom, award end date >= run date' do
      let(:date_last_certified) { Date.new(2025, 1, 31) }
      let(:award_begin_date) { Date.new(2025, 2, 28) }
      let(:award_end_date) { Date.new(2025, 3, 15) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create a pending verification based on eval_case_eom' do
        expect_contra(Date.new(2025, 2, 28), 'case_eom')
      end
    end

    # begin date is prior to eom and end date is prior to eom
    describe 'run date is eom, award begin date < run date, award end date < run date' do
      let(:date_last_certified) { Date.new(2025, 1, 31) }
      let(:award_begin_date) { Date.new(2025, 2, 1) }
      let(:award_end_date) { Date.new(2025, 2, 27) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create a pending verification based on eval_case_eom' do
        expect_contra(Date.new(2025, 2, 28), 'case_eom')
      end
    end

    describe 'cur_award_ind is P(ast)' do
      let(:date_last_certified) { Date.new(2025, 1, 15) }

      before { setup_past_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'creates a pending award with a award begin date for act_begin and today for act_end' do
        Timecop.freeze(Date.new(2025, 2, 28)) { subject.create }

        pending_verification = Vye::Verification.first
        expect(pending_verification.trace).to eq('case_eom')
      end
    end

    describe 'cur_award_ind is F(uture)' do
      let(:date_last_certified) { Date.new(2025, 1, 15) }

      before { setup_future_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'creates a pending award with a award begin date for act_begin and today for act_end' do
        Timecop.freeze(Date.new(2025, 2, 28)) { subject.create }

        pending_verification = Vye::Verification.first
        expect(pending_verification.trace).to eq('case_eom')
      end
    end
  end
end
