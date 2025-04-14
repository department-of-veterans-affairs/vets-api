# frozen_string_literal: true

Rspec.shared_context 'shared_award_helpers' do
  # Basic setup across all pending verification specs
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
  #

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

  # We really don't care about exceptions here, we're concerned with
  # whether a certain type of pending verification is/isn't created
  # rubocop:disable Lint/SuppressedException
  def expect_contra(run_date, trace)
    begin
      Timecop.freeze(run_date) { subject.create }
    rescue Vye::V1::VerificationsController::AwardsMismatch
    end

    pending_verification = Vye::Verification.where(trace:).last
    expect(pending_verification).to be_nil
  end
  # rubocop:enable Lint/SuppressedException

  def check_expectations_for(pending_verification, act_beg_dt, act_end_dt, xact_dt, trace)
    expect(pending_verification.act_begin.to_date).to eq(act_beg_dt)
    expect(pending_verification.act_end.to_date).to eq(act_end_dt)
    expect(pending_verification.transact_date).to eq(xact_dt)
    expect(pending_verification.trace).to eq(trace)
  end
end
