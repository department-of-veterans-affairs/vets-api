# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  describe 'implied award end date' do
    subject { described_class.new }

    let(:date_last_certified) { Date.new(2025, 3, 1) }
    let(:payment_date) { Date.new(2025, 3, 1) }
    let(:last_day_of_prior_month) { Date.new(2025, 3, 31) }
    let(:run_date) { Date.new(2025, 4, 15) }

    ###########################################################
    # glossary
    ###########################################################
    # award begin date (abd)
    # date last certified (dlc)
    # award end date (aed)
    # last day of prior month (ldpm)
    # run date (rd)

    # Sometimes the award end date is not explicitly set in the middle of a
    # sequence of awards. If it is not the last (most recent) award in the
    # sequence, it's implied award end date is the begin date of the next
    # award in the sequence minus 1 day.

    # rubocop:disable Naming/VariableNumber
    describe 'implied award end date' do
      let(:award_begin_date) { Date.new(2025, 3, 2) }
      let(:award_end_date) { nil } # implied to 3/15
      let(:award_begin_date_2) { Date.new(2025, 3, 16) }
      let(:award_end_date_2) { Date.new(2025, 4, 2) }

      # The first award will be handled by the shared context
      before do
        setup_award(award_begin_date: award_begin_date_2, award_end_date: award_end_date_2, payment_date:)
      end

      # rubocop:disable Rspec/NoExpectationExample
      it 'creates a pending verification for the 1st row with an act end of 3/14' do
        Timecop.freeze(run_date) { subject.create }
        pv = Vye::Verification.first
        check_expectations_for(pv, award_begin_date, Date.new(2025, 3, 14), Date.new(2025, 4, 1), 'case5')
      end
      # rubocop:enable Rspec/NoExpectationExample
    end
    # rubocop:enable Naming/VariableNumber

    describe 'open award' do
      let(:award_begin_date) { Date.new(2025, 3, 2) }
      let(:award_end_date) { nil } # no implication, award is open

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create a pending verification' do
        expect(Vye::Verification.count).to eq(0)
      end
    end
  end
end
