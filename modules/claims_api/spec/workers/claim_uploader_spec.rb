# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ClaimUploader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
    allow(Flipper).to receive(:enabled?).with(:claims_claim_uploader_use_bd).and_return false
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:supporting_document) do
    claim = create(:auto_established_claim_with_supporting_documents, :status_established)
    supporting_document = claim.supporting_documents[0]
    supporting_document.set_file_data!(
      Rack::Test::UploadedFile.new(
        ::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
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
        ::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    supporting_document.save!
    supporting_document
  end

  let(:auto_claim) do
    claim = create(:auto_established_claim, evss_id: '12345')
    claim.set_file_data!(
      Rack::Test::UploadedFile.new(
        ::Rails.root.join(*'/modules/claims_api/spec/fixtures/extras.pdf'.split('/')).to_s
      ),
      'docType',
      'description'
    )
    claim.save!
    claim
  end

  it 'submits successfully' do
    expect do
      subject.perform_async(supporting_document.id)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'submits successfully with BD' do
    allow(Flipper).to receive(:enabled?).with(:claims_claim_uploader_use_bd).and_return true
    allow_any_instance_of(ClaimsApi::BD).to receive(:upload).and_return true

    subject.new.perform(supporting_document.id)
    supporting_document.reload
    expect(auto_claim.uploader.blank?).to eq(false)
  end

  # relates to API-14302 and API-14303
  # do not remove uploads from S3 until we feel that uploads to EVSS are stable
  it 'on successful call it does not delete the file from S3' do
    evss_service_stub = instance_double('EVSS::DocumentsService')
    allow(EVSS::DocumentsService).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:upload) { OpenStruct.new(response: 200) }

    subject.new.perform(supporting_document.id)
    supporting_document.reload
    expect(supporting_document.uploader.blank?).to eq(false)
  end

  it 'if an evss_id is nil, it reschedules the sidekiq job to the future' do
    evss_service_stub = instance_double('EVSS::DocumentsService')
    allow(EVSS::DocumentsService).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:upload) { OpenStruct.new(response: 200) }

    subject.new.perform(supporting_document_failed_submission.id)
    supporting_document_failed_submission.reload
    expect(supporting_document.uploader.blank?).to eq(false)
  end

  it 'transforms a claim document to the right properties for EVSS' do
    evss_service_stub = instance_double('EVSS::DocumentsService')
    allow(EVSS::DocumentsService).to receive(:new) { evss_service_stub }
    expect(evss_service_stub).to receive(:upload).with(any_args, OpenStruct.new(
                                                                   file_name: supporting_document.file_name,
                                                                   document_type: supporting_document.document_type,
                                                                   description: supporting_document.description,
                                                                   evss_claim_id: supporting_document.evss_claim_id,
                                                                   tracked_item_id: supporting_document.tracked_item_id
                                                                 ))

    subject.new.perform(supporting_document.id)

    supporting_document.reload
    expect(supporting_document.uploader.blank?).to eq(false)
  end

  it 'transforms a 526 claim form to the right properties for EVSS' do
    evss_service_stub = instance_double('EVSS::DocumentsService')
    allow(EVSS::DocumentsService).to receive(:new) { evss_service_stub }

    expect(evss_service_stub).to receive(:upload).with(any_args, OpenStruct.new(
                                                                   file_name: auto_claim.file_name,
                                                                   document_type: auto_claim.document_type,
                                                                   description: auto_claim.description,
                                                                   evss_claim_id: auto_claim.evss_id,
                                                                   tracked_item_id: auto_claim.id
                                                                 ))

    subject.new.perform(auto_claim.id)

    auto_claim.reload
    expect(auto_claim.uploader.blank?).to eq(false)
  end
end
