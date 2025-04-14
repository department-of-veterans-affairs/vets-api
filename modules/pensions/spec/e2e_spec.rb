# frozen_string_literal: true

require 'rails_helper'
require 'pensions/benefits_intake/submission_handler'
require 'pensions/benefits_intake/pension_benefit_intake_job'
require 'pensions/monitor'
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
require 'kafka/sidekiq/event_bus_submission_job'

RSpec.describe 'Pensions End to End', type: :request do
  let(:form) { build(:pensions_saved_claim) }
  let(:param_name) { :pension_claim }
  let(:pdf_path) { 'random/path/to/pdf' }
  let(:monitor) { Pensions::Monitor.new }
  let(:service) { BenefitsIntake::Service.new }

  let(:stats_key) { BenefitsIntake::SubmissionStatusJob::STATS_KEY }

  before do
    allow(Pensions::Monitor).to receive(:new).and_return(monitor)
    allow(BenefitsIntake::Service).to receive(:new).and_return(service)

    allow(Flipper).to receive(:enabled?).with(anything).and_call_original
    allow(Flipper).to receive(:enabled?).with(:pension_submitted_email_notification).and_return true
    allow(Flipper).to receive(:enabled?).with(:benefits_intake_submission_status_job).and_return true
  end

  it 'successfully completes the submission process' do
    # form submission
    expect(Pensions::SavedClaim).to receive(:new).with(form: form.form).and_call_original
    expect(monitor).to receive(:track_create_attempt).and_call_original
    expect(SavedClaimSerializer).to receive(:new).and_call_original
    expect(PersistentAttachment).to receive(:where).with(guid: anything).and_call_original
    expect(Pensions::PensionBenefitIntakeJob).to receive(:perform_async)
    expect(Kafka::EventBusSubmissionJob).to receive(:perform_async).twice.and_call_original
    expect(monitor).to receive(:track_create_success).and_call_original

    post '/pensions/v0/claims', params: { param_name => { form: form.form } }
    expect(response).to have_http_status(:success)

    data = response.parsed_body['data']
    saved_claim_id = data['id'].to_i

    # verify claim created
    pension_claim = Pensions::SavedClaim.find(saved_claim_id)
    expect(pension_claim).to be_present
    expect(pension_claim.confirmation_number).to eq data['attributes']['confirmation_number']

    # claim upload to benefits intake
    expect(BenefitsIntake::Metadata).to receive(:generate).and_call_original

    expect(service).to receive(:valid_document?).and_return(pdf_path)
    expect(service).to receive(:request_upload)
    expect(monitor).to receive(:track_submission_begun).and_call_original

    expect(FormSubmission).to receive(:create).and_call_original
    expect(FormSubmissionAttempt).to receive(:create).and_call_original
    expect(Datadog::Tracing).to receive(:active_trace).and_call_original

    expect(service).to receive(:location)

    expect(monitor).to receive(:track_submission_attempted).and_call_original
    expect(service).to receive(:perform_upload).and_return(double(success?: true))

    email = Pensions::NotificationEmail.new(saved_claim_id)
    allow(Pensions::NotificationEmail).to receive(:new).and_return(email)

    # 'success' email notification
    expect(email).to receive(:deliver).with(:submitted).and_call_original
    expect(VANotify::EmailJob).to receive(:perform_async)
    expect(VeteranFacingServices::NotificationEmail).to receive(:monitor_deliver_success).and_call_original

    expect(monitor).to receive(:track_submission_success).and_call_original
    expect(Common::FileHelpers).to receive(:delete_file_if_exists).at_least(1).and_call_original

    lh_bi_uuid = Pensions::PensionBenefitIntakeJob.new.perform(saved_claim_id)

    # verify upload artifacts - form_submission and claim_va_notification
    submission = FormSubmission.find_by(saved_claim_id:)
    expect(submission).to be_present

    attempt = submission.latest_pending_attempt
    expect(attempt).to be_present
    expect(attempt.aasm_state).to eq 'pending'
    expect(attempt.benefits_intake_uuid).to eq lh_bi_uuid

    notification = ClaimVANotification.find_by(saved_claim_id:)
    expect(notification).to be_present

    # submission status update
    updated_at = Time.zone.now
    attributes = { 'status' => 'vbms', 'updated_at' => updated_at }
    data = [{ 'id' => attempt.benefits_intake_uuid, 'attributes' => attributes }]
    bulk_status = double(body: { 'data' => data }, success?: true)

    expect(service).to receive(:bulk_status).and_return(bulk_status)

    handler = Pensions::BenefitsIntake::SubmissionHandler.new(saved_claim_id)
    expect(Pensions::BenefitsIntake::SubmissionHandler).to receive(:new).with(saved_claim_id).and_return(handler)
    expect(handler).to receive(:handle).with('success', anything).and_call_original

    expect(email).to receive(:deliver).with(:received).and_call_original
    expect(VANotify::EmailJob).to receive(:perform_async)
    expect(VeteranFacingServices::NotificationEmail).to receive(:monitor_deliver_success).and_call_original

    BenefitsIntake::SubmissionStatusJob.new.perform(Pensions::FORM_ID)

    updated = attempt.reload
    expect(updated.aasm_state).to eq 'vbms'
    expect(updated.lighthouse_updated_at).to be_the_same_time_as updated_at
    expect(updated.error_message).to be_nil
  end
end
