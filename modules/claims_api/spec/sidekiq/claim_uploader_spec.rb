# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ClaimUploader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    allow(Flipper).to receive(:enabled?).with(:claims_api_bd_refactor).and_return false
    allow(Flipper).to receive(:enabled?).with(:claims_claim_uploader_use_bd).and_return false
    allow(Flipper).to receive(:enabled?).with(:claims_load_testing).and_return false
  end

  let(:user) { create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:supporting_document) do
    claim = create(:auto_established_claim_with_supporting_documents, :established)
    supporting_document = claim.supporting_documents[0]
    supporting_document.set_file_data!(
      Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    supporting_document.save!
    supporting_document
  end

  let(:supporting_document_failed_submission) do
    supporting_document = create(:supporting_document)
    supporting_document.set_file_data!(
      Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    supporting_document.save!
    supporting_document
  end

  let(:auto_claim) do
    claim = create(:auto_established_claim, evss_id: '12345', status: 'pending')
    claim.set_file_data!(
      Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    claim.save!
    claim
  end

  let(:pending_auto_claim) do
    claim = create(:auto_established_claim, evss_id: nil, status: 'pending')
    claim.set_file_data!(
      Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    claim.save!
    claim
  end

  let(:errored_auto_claim) do
    claim = create(:auto_established_claim, evss_id: nil, status: 'errored')
    claim.set_file_data!(
      Rack::Test::UploadedFile.new(
        Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    claim.save!
    claim
  end

  let(:original_filename) { 'extras' }

  it 'submits successfully' do
    expect do
      subject.perform_async(supporting_document.id)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'submits successfully with BD' do
    expect_any_instance_of(ClaimsApi::BD).to receive(:upload).and_return true

    subject.new.perform(supporting_document.id, 'document')
    supporting_document.reload
    expect(auto_claim.uploader.blank?).to be(false)
  end

  it 'if an evss_id is nil, and claim is errored, it does not reschedule the sidekiq job to the future' do
    expect_any_instance_of(subject).to receive(:slack_alert_on_failure)

    subject.new.perform(errored_auto_claim.id, 'claim')
    expect(subject.jobs).to eq([])
  end

  it 'calls slack_alert_on_failure with appropriate message if claim of type "claim" is errored' do
    msg = 'Claim Uploader job failed to upload 526EZ PDF to Benefits Documents ' \
          "API due to claim submission error for claim #{errored_auto_claim.id}"
    expect_any_instance_of(subject).to receive(:slack_alert_on_failure).with('ClaimsApi::ClaimUploader', msg)
    subject.new.perform(errored_auto_claim.id, 'claim')
  end

  it 'calls slack_alert_on_failure with appropriate message if claim of type "document" is errored' do
    msg = "Claim Uploader job failed to upload attachment #{errored_auto_claim.id} " \
          "to Benefits Documents API due to claim submission error for claim #{errored_auto_claim.id}"
    expect_any_instance_of(subject).to receive(:slack_alert_on_failure).with('ClaimsApi::ClaimUploader', msg)
    subject.new.perform(errored_auto_claim.id, 'document')
  end

  describe 'BD document type' do
    it 'is a 526' do
      tf = Tempfile.new(['pdf_path', '.pdf'], binmode: true)
      allow(Tempfile).to receive(:new).and_return tf
      allow(Flipper).to receive(:enabled?).with(:claims_claim_uploader_use_bd).and_return true

      args = { claim: auto_claim, doc_type: 'L122', original_filename: 'extras.pdf', pdf_path: tf.path }
      expect_any_instance_of(ClaimsApi::BD).to receive(:upload).with(args).and_return true
      subject.new.perform(auto_claim.id, 'claim')
    end

    it 'is an attachment' do
      tf = Tempfile.new(['pdf_path', '.pdf'], binmode: true)
      allow(Tempfile).to receive(:new).and_return tf
      allow(Flipper).to receive(:enabled?).with(:claims_claim_uploader_use_bd).and_return true

      args = { claim: supporting_document.auto_established_claim, doc_type: 'L023',
               original_filename: 'extras.pdf', pdf_path: tf.path }
      expect_any_instance_of(ClaimsApi::BD).to receive(:upload).with(args).and_return true
      subject.new.perform(supporting_document.id, 'document')
    end

    it 'is an attachment resulting in error' do
      tf = Tempfile.new(['pdf_path', '.pdf'], binmode: true)
      allow(Tempfile).to receive(:new).and_return tf
      allow(Flipper).to receive(:enabled?).with(:claims_claim_uploader_use_bd).and_return true

      body = {
        messages: [
          { key: '',
            severity: 'ERROR',
            text: 'Error calling external service to upload claim document.' }
        ]
      }
      args = { claim: supporting_document.auto_established_claim, doc_type: 'L023',
               original_filename: 'extras.pdf', pdf_path: tf.path }
      allow_any_instance_of(ClaimsApi::BD).to(
        receive(:upload).with(args).and_raise(Common::Exceptions::BackendServiceException.new(
                                                '', {}, 500, body
                                              ))
      )
      expect do
        subject.new.perform(supporting_document.id, 'document')
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the Claim Uploader Job'
      msg = { 'args' => [auto_claim.id],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: auto_claim.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end
end
