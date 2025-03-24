# frozen_string_literal: true
require 'rails_helper'
require 'support/controller_spec_helper'

# rubocop:disable RSpec/SubjectStub
RSpec.describe Vye::V1::VerificationsController, type: :controller do
  let!(:current_user) { create(:user, :accountable) }
  let!(:user_profile) { create(:vye_user_profile, icn: current_user.icn) }
  let!(:user_info) { create(:vye_user_info, user_profile:, date_last_certified:) }
  let(:cur_award_ind) { Vye::Award.cur_award_inds[:current] }

  before do
    sign_in_as(current_user)
    allow_any_instance_of(ApplicationController).to receive(:validate_session).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(Vye::V1::VerificationsController).to receive(:authorize).and_return(true)
  end

  # 1) run date is the end of the month
  # 2) the award begin date is b4 the run date and the award end date is not b4 the run date
  # Note: the current award indicator is NOT considered for this case
  describe 'eval_case_eom' do
    subject { described_class.new }

    let(:payment_date) { Date.new(2025, 2, 15) }
    let(:award_begin_date) { Date.new(2025, 2, 9) }
    let(:award_end_date) { Date.new(2025, 3, 1) }

    # there are two outcomes for happy path end of month
    # a) today is the end of the month
    # b) award_begin date is before today
    # c) award end date is not before today
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
        # Throws AwardsMismatch
        Timecop.freeze(Date.new(2025, 2, 27)) do
          expect { subject.create }.to raise_error(Vye::V1::VerificationsController::AwardsMismatch)
        end

        pending_verification = Vye::Verification.where(trace: 'case_eom').last
        expect(pending_verification).to be_nil
      end
    end

    describe 'run date is not the end of the month (day later)' do
      let(:date_last_certified) { Date.new(2025, 1, 31) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create a pending verification based on eval_case_eom' do
        Timecop.freeze(Date.new(2025, 3, 1)) { subject.create }

        pending_verification = Vye::Verification.where(trace: 'case_eom').last
        expect(pending_verification).to be_nil
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
        # Throws AwardsMismatch
        Timecop.freeze(Date.new(2025, 2, 28)) do
          expect { subject.create }.to raise_error(Vye::V1::VerificationsController::AwardsMismatch)
        end

        pending_verification = Vye::Verification.where(trace: 'case_eom').last
        expect(pending_verification).to be_nil
      end
    end

    # begin date is prior to eom and end date is prior to eom
    describe 'run date is eom, award begin date < run date, award end date < run date' do
      let(:date_last_certified) { Date.new(2025, 1, 31) }
      let(:award_begin_date) { Date.new(2025, 2, 1) }
      let(:award_end_date) { Date.new(2025, 2, 27) }

      before { setup_award(award_begin_date:, award_end_date:, payment_date:) }

      it 'does not create a pending verification based on eval_case_eom' do
        # Throws AwardsMismatch
        Timecop.freeze(Date.new(2025, 2, 28)) do
          expect { subject.create }.to raise_error(Vye::V1::VerificationsController::AwardsMismatch)
        end

        pending_verification = Vye::Verification.where(trace: 'case_eom').last
        expect(pending_verification).to be_nil
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

    def setup_award(award_begin_date:, award_end_date:, payment_date:)
      create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind:, payment_date:)
      setup_controller
    end

    def setup_past_award(award_begin_date:, award_end_date:, payment_date:)
      create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind: 'P', payment_date:)
      setup_controller
    end

    def setup_future_award(award_begin_date:, award_end_date:, payment_date:)
      create(:vye_award, user_info:, award_begin_date:, award_end_date:, cur_award_ind: 'F', payment_date:)
      setup_controller
    end

    def setup_controller
      award_ids = user_info.awards.pluck(:id)
      params = { award_ids: }
      allow(subject).to receive_messages(params:, current_user:, head: :no_content)
      subject.send(:load_user_info)
    end
  end
end
# rubocop:enable RSpec/SubjectStub
