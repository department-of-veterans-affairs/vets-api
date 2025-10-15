# frozen_string_literal: true

require 'rails_helper'
require 'increase_compensation/benefits_intake/submission_handler'
require 'increase_compensation/benefits_intake/submit_claim_job'
require 'increase_compensation/monitor'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

RSpec.describe 'Increase Compensation End to End', skip: 'TODO after schema built', type: :request do
  let(:form) { build(:increase_compensation_claim) }
  let(:param_name) { :increase_compensation_claim }
  let(:pdf_path) { 'random/path/to/pdf' }
  let(:monitor) { IncreaseCompensation::Monitor.new }
  let(:service) { BenefitsIntake::Service.new }

  let(:stats_key) { BenefitsIntake::SubmissionStatusJob::STATS_KEY }

  before do
    allow(IncreaseCompensation::Monitor).to receive(:new).and_return(monitor)
    allow(BenefitsIntake::Service).to receive(:new).and_return(service)

    allow(Flipper).to receive(:enabled?).with(anything).and_call_original
    allow(Flipper).to receive(:enabled?).with(:increase_compensation_submitted_email_notification).and_return true
    allow(Flipper).to receive(:enabled?).with(:benefits_intake_submission_status_job).and_return true
  end

  it 'successfully completes the submission process' do
    # form submission
    expect(IncreaseCompensation::SavedClaim).to receive(:new).with(form: form.form).and_call_original
    expect(monitor).to receive(:track_create_attempt).and_call_original
    expect(SavedClaimSerializer).to receive(:new).and_call_original
    expect(PersistentAttachment).to receive(:where).with(guid: anything).and_call_original
    expect(IncreaseCompensation::BenefitsIntake::SubmitClaimJob).to receive(:perform_async)
    expect(monitor).to receive(:track_create_success).and_call_original

    post '/increase_compensation/v0/claims', params: { param_name => { form: form.form } }
    expect(response).to have_http_status(:success)

    data = response.parsed_body['data']
    saved_claim_id = data['id'].to_i

    # verify claim created
    increase_compensation_claim = IncreaseCompensation::SavedClaim.find(saved_claim_id)
    expect(increase_compensation_claim).to be_present
    expect(increase_compensation_claim.confirmation_number).to eq data['attributes']['confirmation_number']

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

    email = IncreaseCompensation::NotificationEmail.new(saved_claim_id)
    allow(IncreaseCompensation::NotificationEmail).to receive(:new).and_return(email)

    # 'success' email notification
    expect(email).to receive(:deliver).with(:submitted).and_call_original
    expect(VANotify::EmailJob).to receive(:perform_async)
    expect(VeteranFacingServices::NotificationEmail).to receive(:monitor_deliver_success).and_call_original

    expect(monitor).to receive(:track_submission_success).and_call_original
    expect(Common::FileHelpers).to receive(:delete_file_if_exists).at_least(1).and_call_original

    lh_bi_uuid = IncreaseCompensation::BenefitsIntake::SubmitClaimJob.new.perform(saved_claim_id)

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
    expect(VANotify::EmailJob).to receive(:perform_async)
    expect(VeteranFacingServices::NotificationEmail).to receive(:monitor_deliver_success).and_call_original

    BenefitsIntake::SubmissionStatusJob.new.perform(IncreaseCompensation::FORM_ID)

    updated = attempt.reload
    expect(updated.status).to eq 'vbms'
    expect(updated.lighthouse_updated_at).to be_the_same_time_as updated_at
    expect(updated.error_message).to be_nil
  end
end
