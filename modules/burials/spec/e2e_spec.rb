# frozen_string_literal: true

require 'rails_helper'
require 'burials/benefits_intake/submit_claim_job'
require 'burials/monitor'

RSpec.describe 'Burials End to End', type: :request do

  let(:form) { build(:burials_saved_claim) }
  let(:param_name) { :burial_claim }
  let(:pdf_path) { 'random/path/to/pdf' }
  let(:monitor) { Burials::Monitor.new }
  let(:service) { ::BenefitsIntake::Service.new }

  before do
    allow(Burials::Monitor).to receive(:new).and_return(monitor)
    allow(::BenefitsIntake::Service).to receive(:new).and_return(service)
  end

  it 'successfully completes the submission process' do
    # form submission
    expect(Burials::SavedClaim).to receive(:new).with(form: form.form).and_call_original
    expect(monitor).to receive(:track_create_attempt).and_call_original
    expect(SavedClaimSerializer).to receive(:new).and_call_original
    expect(PersistentAttachment).to receive(:where).with(guid: anything).and_call_original
    expect(Burials::BenefitsIntake::SubmitClaimJob).to receive(:perform_async)
    expect(monitor).to receive(:track_create_success).and_call_original

    post '/burials/v0/claims', params: { param_name => { form: form.form } }
    expect(response).to have_http_status(:success)

    data = response.parsed_body['data']
    saved_claim_id = data['id']

    # veify claim created
    burial_claim = Burials::SavedClaim.find(saved_claim_id)
    expect(burial_claim).to be_present
    expect(burial_claim.confirmation_number).to eq data['attributes']['confirmation_number']

    # claim upload to benefits intake
    expect(::BenefitsIntake::Metadata).to receive(:generate).and_call_original

    expect(service).to receive(:valid_document?).and_return(pdf_path)
    expect(service).to receive(:request_upload)
    expect(monitor).to receive(:track_submission_begun).and_call_original

    expect(FormSubmission).to receive(:create).and_call_original
    expect(FormSubmissionAttempt).to receive(:create).and_call_original
    expect(Datadog::Tracing).to receive(:active_trace).and_call_original

    expect(service).to receive(:location)

    expect(monitor).to receive(:track_submission_attempted).and_call_original
    expect(service).to receive(:perform_upload).and_return(double(success?: true))

    # 'success' email notification
    email = Burials::NotificationEmail.new(saved_claim_id)
    expect(Burials::NotificationEmail).to receive(:new).and_return(email)
    expect(email).to receive(:deliver).with(:submitted).and_call_original
    expect(VANotify::EmailJob).to receive(:perform_async)
    expect(VeteranFacingServices::NotificationEmail).to receive(:monitor_deliver_success).and_call_original

    expect(monitor).to receive(:track_submission_success).and_call_original
    expect(Common::FileHelpers).to receive(:delete_file_if_exists).at_least(1).and_call_original

    lh_bi_uuid = Burials::BenefitsIntake::SubmitClaimJob.new.perform(saved_claim_id)

    # verify upload artifacts - form_submission and claim_va_notification
    submission = FormSubmission.find_by(saved_claim_id:)
    expect(submission).to be_present

    attempt = submission.latest_pending_attempt
    expect(attempt).to be_present
    expect(attempt.benefits_intake_uuid).to eq lh_bi_uuid

    notification = ClaimVANotification.find_by(saved_claim_id:)
    expect(notification).to be_present

    # submission status update
  end
end
