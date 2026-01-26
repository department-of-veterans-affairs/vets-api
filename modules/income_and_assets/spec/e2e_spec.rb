# frozen_string_literal: true

require 'rails_helper'
require 'income_and_assets/benefits_intake/submission_handler'
require 'income_and_assets/benefits_intake/submit_claim_job'
require 'income_and_assets/monitor'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

RSpec.describe 'Income and Assets End to End', type: :request do
  let(:form) { build(:income_and_assets_claim) }
  let(:param_name) { :income_and_assets_claim }
  let(:pdf_path) { 'random/path/to/pdf' }
  let(:monitor) { IncomeAndAssets::Monitor.new }
  let(:service) { BenefitsIntake::Service.new }
  let(:vanotify) { double(send_email: true) }

  let(:stats_key) { BenefitsIntake::SubmissionStatusJob::STATS_KEY }

  before do
    allow(IncomeAndAssets::Monitor).to receive(:new).and_return(monitor)
    allow(BenefitsIntake::Service).to receive(:new).and_return(service)

    allow(VaNotify::Service).to receive(:new).and_return(vanotify)

    allow(Flipper).to receive(:enabled?).with(anything).and_call_original
    allow(Flipper).to receive(:enabled?).with(:income_and_assets_submitted_email_notification).and_return true
    allow(Flipper).to receive(:enabled?).with(:benefits_intake_submission_status_job).and_return true
  end

  it 'successfully completes the submission process' do
    # form submission
    expect(IncomeAndAssets::SavedClaim).to receive(:new).with(form: form.form).and_call_original
    expect(monitor).to receive(:track_create_attempt).and_call_original
    expect(SavedClaimSerializer).to receive(:new).and_call_original
    expect(PersistentAttachment).to receive(:where).with(guid: anything).and_call_original
    expect(IncomeAndAssets::BenefitsIntake::SubmitClaimJob).to receive(:perform_async)
    expect(monitor).to receive(:track_create_success).and_call_original

    post '/income_and_assets/v0/claims', params: { param_name => { form: form.form } }
    expect(response).to have_http_status(:success)

    data = response.parsed_body['data']
    saved_claim_id = data['id'].to_i

    # verify claim created
    income_and_assets_claim = IncomeAndAssets::SavedClaim.find(saved_claim_id)
    expect(income_and_assets_claim).to be_present
    expect(income_and_assets_claim.confirmation_number).to eq data['attributes']['confirmation_number']

    # claim upload to benefits intake
    expect(BenefitsIntake::Metadata).to receive(:generate).and_call_original

    expect(service).to receive(:valid_document?).and_return(pdf_path)
    expect(service).to receive(:request_upload)
    expect(monitor).to receive(:track_submission_begun).and_call_original

    expect(Lighthouse::Submission).to receive(:create).and_call_original
    expect(Lighthouse::SubmissionAttempt).to receive(:create).and_call_original
    expect(Datadog::Tracing).to receive(:active_trace).and_call_original

    expect(service).to receive(:location)

    expect(monitor).to receive(:track_submission_attempted).and_call_original
    expect(service).to receive(:perform_upload).and_return(double(success?: true))

    email = IncomeAndAssets::NotificationEmail.new(saved_claim_id)
    allow(IncomeAndAssets::NotificationEmail).to receive(:new).and_return(email)

    # 'success' email notification
    expect(email).to receive(:deliver).with(:submitted).and_call_original
    expect(vanotify).to receive(:send_email)

    expect(monitor).to receive(:track_submission_success).and_call_original
    expect(Common::FileHelpers).to receive(:delete_file_if_exists).at_least(1).and_call_original

    # submission process, external api is stubbed - BenefitsIntake::Service methods above
    lh_bi_uuid = IncomeAndAssets::BenefitsIntake::SubmitClaimJob.new.perform(saved_claim_id)

    # verify upload artifacts - form_submission and claim_va_notification
    submission = Lighthouse::Submission.find_by(saved_claim_id:)
    expect(submission).to be_present

    attempt = submission.latest_pending_attempt
    expect(attempt).to be_present
    expect(attempt.status).to eq 'pending'
    expect(attempt.benefits_intake_uuid).to eq lh_bi_uuid

    notification = ClaimVANotification.find_by(saved_claim_id:)
    expect(notification).to be_present

    # submission status update
    updated_at = Time.zone.now
    attributes = { 'status' => 'vbms', 'updated_at' => updated_at }
    data = [{ 'id' => attempt.benefits_intake_uuid, 'attributes' => attributes }]
    bulk_status = double(body: { 'data' => data }, success?: true)

    expect(service).to receive(:bulk_status).and_return(bulk_status)

    expect(email).to receive(:deliver).with(:received).and_call_original
    expect(vanotify).to receive(:send_email)

    # update submission status, external api is stubbed - BenefitsIntake::Service#bulk_status above
    BenefitsIntake::SubmissionStatusJob.new.perform(IncomeAndAssets::FORM_ID)

    updated = attempt.reload
    expect(updated.status).to eq 'vbms'
    expect(updated.lighthouse_updated_at).to be_the_same_time_as updated_at
    expect(updated.error_message).to be_nil
  end
end
