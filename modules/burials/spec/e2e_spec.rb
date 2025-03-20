# frozen_string_literal: true

require 'rails_helper'
require 'burials/benefits_intake/submit_claim_job'
require 'burials/monitor'

RSpec.describe 'Burials End to End', type: :request do

  let(:form) { build(:burials_saved_claim) }
  let(:param_name) { :burial_claim }
  let(:pdf_path) { 'random/path/to/pdf' }

  it 'successfully completes the submission process' do
    expect(Burials::Monitor).to receive(:new).and_call_original
    expect(Burials::SavedClaim).to receive(:new).with(form: form.form).and_call_original
    expect(SavedClaimSerializer).to receive(:new).and_call_original
    expect(PersistentAttachment).to receive(:where).with(guid: anything).and_call_original
    expect(Burials::BenefitsIntake::SubmitClaimJob).to receive(:perform_async)

    post '/burials/v0/claims', params: { param_name => { form: form.form } }
    expect(response).to have_http_status(:success)

    data = response.parsed_body['data']
    saved_claim_id = data['id']

    burial_claim = Burials::SavedClaim.find(saved_claim_id)
    expect(burial_claim.confirmation_number).to eq data['attributes']['confirmation_number']
    expect(FormSubmission.find_by(saved_claim_id:)).to be_nil

    expect(Burials::Monitor).to receive(:new).and_call_original
    expect(::BenefitsIntake::Metadata).to receive(:generate).and_call_original

    expect_any_instance_of(::BenefitsIntake::Service).to receive(:valid_document?).and_return(pdf_path)
    expect_any_instance_of(::BenefitsIntake::Service).to receive(:request_upload)
    expect_any_instance_of(::BenefitsIntake::Service).to receive(:location)
    expect_any_instance_of(::BenefitsIntake::Service).to receive(:perform_upload).and_return(double(success?: true))

    expect_any_instance_of(Burials::NotificationEmail).to receive(:deliver).and_call_original
    expect(VANotify::EmailJob).to receive(:perform_async)
    expect(VeteranFacingServices::NotificationEmail).to receive(:monitor_deliver_success).and_call_original

    expect(Common::FileHelpers).to receive(:delete_file_if_exists).at_least(1).and_call_original

    Burials::BenefitsIntake::SubmitClaimJob.new.perform(saved_claim_id)

    submission = FormSubmission.find_by(saved_claim_id:)
    expect(submission).to be_present
    expect(submission.latest_pending_attempt).to be_present

    notification = ClaimVANotification.find_by(saved_claim_id:)
    expect(notification).to be_present
  end
end
