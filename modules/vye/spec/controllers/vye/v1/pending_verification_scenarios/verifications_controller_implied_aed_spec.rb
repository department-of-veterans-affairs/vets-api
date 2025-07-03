# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'
require_relative '../../../../support/shared_award_helpers'

RSpec.describe Vye::V1::VerificationsController, type: :controller do
  include_context 'shared_award_helpers'

  before do
    allow(Flipper).to receive(:enabled?).with(:disable_bdn_processing).and_return(false)
  end

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
    describe 'implied award end date in previous month' do
      let(:award_begin_date) { Date.new(2025, 3, 2) }
      let(:award_end_date) { nil } # implied to 3/15
      let(:award_begin_date_2) { Date.new(2025, 3, 16) }
      let(:award_end_date_2) { Date.new(2025, 4, 2) }

      # The first award will be handled by the shared context
      before do
        setup_award(award_begin_date: award_begin_date_2, award_end_date: award_end_date_2, payment_date:)
      end

      # rubocop:disable RSpec/NoExpectationExample
      it 'creates a pending verification for the 1st row with an act end of 3/14' do
        Timecop.freeze(run_date) { subject.create }
        pv = Vye::Verification.first
        check_expectations_for(pv, award_begin_date, Date.new(2025, 3, 14), Date.new(2025, 4, 1), 'case5')
      end
      # rubocop:enable RSpec/NoExpectationExample
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

    # rubocop:disable Naming/VariableNumber
    describe 'implied award end date in current month with award begin in previous month' do
      let(:award_begin_date) { Date.new(2025, 3, 15) } # Previous month (March)
      let(:award_end_date) { nil } # would be implied to 4/10, in current month
      let(:award_begin_date_2) { Date.new(2025, 4, 11) }
      let(:award_end_date_2) { Date.new(2025, 5, 30) }
      let(:user_info) { create(:vye_user_info, date_last_certified:) }
      let(:award1) do
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, payment_date:)
      end
      let(:award2) do
        create(:vye_award, user_info:, award_begin_date: award_begin_date_2, award_end_date: award_end_date_2,
                           payment_date:)
      end

      it 'creates a verification using enhanced logic end date' do
        # Create the awards
        award1
        award2

        # Freeze time for consistent testing
        Timecop.freeze(run_date) do
          # Let UserInfo process its awards
          verifications = user_info.pending_verifications

          # Check that a verification WAS created for the first award
          first_award_verification = verifications.find { |v| v.award_id == award1.id }
          expect(first_award_verification).to be_present

          # The verification should use the last day of previous month as cert through date (March 31st)
          expect(first_award_verification.act_end).to eq(Date.new(2025, 3, 31))
        end
      end
    end
    # rubocop:enable Naming/VariableNumber

    # rubocop:disable Naming/VariableNumber
    describe 'implied award end date in current month with award begin in current month' do
      let(:award_begin_date) { Date.new(2025, 4, 5) } # Current month (April)
      let(:award_end_date) { nil } # would be implied to 4/10, in current month
      let(:award_begin_date_2) { Date.new(2025, 4, 11) }
      let(:award_end_date_2) { Date.new(2025, 5, 30) }
      let(:user_info) { create(:vye_user_info, date_last_certified:) }
      let(:award1) do
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, payment_date:)
      end
      let(:award2) do
        create(:vye_award, user_info:, award_begin_date: award_begin_date_2, award_end_date: award_end_date_2,
                           payment_date:)
      end

      it 'treats award as open cert and does not create a verification' do
        # Create the awards
        award1
        award2

        # Freeze time for consistent testing
        Timecop.freeze(run_date) do
          # Let UserInfo process its awards
          verifications = user_info.pending_verifications

          # Check that no verification was created for the first award
          first_award_verification = verifications.find { |v| v.award_id == award1.id }
          expect(first_award_verification).to be_nil
        end
      end

      context 'when verifying on last day of month' do
        let(:run_date) { Date.new(2025, 4, 30) } # Last day of April

        it 'creates a verification allowing cert through last day of month' do
          # Create the awards
          award1
          award2

          # Freeze time for consistent testing
          Timecop.freeze(run_date) do
            # Let UserInfo process its awards
            verifications = user_info.pending_verifications

            # Check that a verification WAS created for the first award
            first_award_verification = verifications.find { |v| v.award_id == award1.id }
            expect(first_award_verification).to be_present

            # The verification should allow cert through last day of month (April 30th)
            expect(first_award_verification.act_end).to eq(Date.new(2025, 4, 30))
          end
        end
      end
    end
    # rubocop:enable Naming/VariableNumber

    # rubocop:disable Naming/VariableNumber
    describe 'implied award end date in future month with award begin in previous month' do
      let(:award_begin_date) { Date.new(2025, 3, 15) } # Previous month (March)
      let(:award_end_date) { nil } # would be implied to 5/14, in future month
      let(:award_begin_date_2) { Date.new(2025, 5, 15) }
      let(:award_end_date_2) { Date.new(2025, 6, 30) }
      let(:user_info) { create(:vye_user_info, date_last_certified:) }
      let(:award1) do
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, payment_date:)
      end
      let(:award2) do
        create(:vye_award, user_info:, award_begin_date: award_begin_date_2, award_end_date: award_end_date_2,
                           payment_date:)
      end

      it 'creates a verification using enhanced logic end date' do
        # Create the awards
        award1
        award2

        # Freeze time for consistent testing
        Timecop.freeze(run_date) do
          # Let UserInfo process its awards
          verifications = user_info.pending_verifications

          # Check that a verification WAS created for the first award
          first_award_verification = verifications.find { |v| v.award_id == award1.id }
          expect(first_award_verification).to be_present

          # The verification should use the last day of previous month as cert through date (March 31st)
          expect(first_award_verification.act_end).to eq(Date.new(2025, 3, 31))
        end
      end
    end
    # rubocop:enable Naming/VariableNumber

    # rubocop:disable Naming/VariableNumber
    describe 'implied award end date in future month with award begin in current month' do
      let(:award_begin_date) { Date.new(2025, 4, 5) } # Current month (April)
      let(:award_end_date) { nil } # would be implied to 5/14, in future month
      let(:award_begin_date_2) { Date.new(2025, 5, 15) }
      let(:award_end_date_2) { Date.new(2025, 6, 30) }
      let(:user_info) { create(:vye_user_info, date_last_certified:) }
      let(:award1) do
        create(:vye_award, user_info:, award_begin_date:, award_end_date:, payment_date:)
      end
      let(:award2) do
        create(:vye_award, user_info:, award_begin_date: award_begin_date_2, award_end_date: award_end_date_2,
                           payment_date:)
      end

      it 'treats award as open cert and does not create a verification' do
        # Create the awards
        award1
        award2

        # Freeze time for consistent testing
        Timecop.freeze(run_date) do
          # Let UserInfo process its awards
          verifications = user_info.pending_verifications

          # Check that no verification was created for the first award
          first_award_verification = verifications.find { |v| v.award_id == award1.id }
          expect(first_award_verification).to be_nil
        end
      end
    end
    # rubocop:enable Naming/VariableNumber
  end
end
