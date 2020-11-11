# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::ClaimUploader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
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
        "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
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
        "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
      ),
      'docType',
      'description'
    )
    supporting_document.save!
    supporting_document
  end

  it 'submits succesfully' do
    expect do
      subject.perform_async(supporting_document.id)
    end.to change(subject.jobs, :size).by(1)
  end

  it 'on successful call and deletes the file' do
    evss_service_stub = instance_double('EVSS::DocumentsService')
    allow(EVSS::DocumentsService).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:upload) { OpenStruct.new(response: 200) }

    subject.new.perform(supporting_document.id)
    supporting_document.reload
    expect(supporting_document.uploader.blank?).to eq(true)
  end

  it 'if an evss_id is nil, it reschedules the sidekiq job to the future' do
    evss_service_stub = instance_double('EVSS::DocumentsService')
    allow(EVSS::DocumentsService).to receive(:new) { evss_service_stub }
    allow(evss_service_stub).to receive(:upload) { OpenStruct.new(response: 200) }

    subject.new.perform(supporting_document_failed_submission.id)
    supporting_document.reload
    expect(supporting_document.uploader.blank?).to eq(false)
  end
end
