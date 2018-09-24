# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:claim_id) { 123_456_789 }
  let(:uploads) do
    [
      { confirmationCode: SecureRandom.uuid },
      { confirmationCode: SecureRandom.uuid },
      { confirmationCode: SecureRandom.uuid },
      { confirmationCode: SecureRandom.uuid }
    ]
  end

  subject { described_class }

  describe '.start' do
    context 'with four uploads' do
      it 'queues four submit upload jobs' do
        expect do
          subject.start(user.uuid, auth_headers, claim_id, uploads)
        end.to change(subject.jobs, :size).by(4)
      end
    end

    context 'with no uploads' do
      let(:uploads) { [] }

      it 'queues no submit upload jobs' do
        expect do
          subject.start(user.uuid, auth_headers, claim_id, uploads)
        end.to_not change(subject.jobs, :size)
      end
    end
  end

  describe 'perform' do
    let(:upload_data) do
      {
        'name' => 'private_medical_record.pdf',
        'confirmationCode' => 'd44d6f52-2e85-43d4-a5a3-1d9cb4e482a0',
        'attachmentId' => 'L451'
      }
    end
    let(:client) { double(:client) }
    let(:document_data) { double(:document_data) }

    before(:each) do
      allow(EVSS::DocumentsService)
        .to receive(:new)
        .and_return(client)
      allow(SupportingEvidenceAttachment)
        .to receive(:find_by)
        .and_return(attachment)
    end

    context 'when file_data exists' do
      let(:attachment) { double(:attachment, file_data: '%PDF-1.3\n') }

      it 'calls the documents service api with file body and document data' do
        expect(EVSSClaimDocument)
          .to receive(:new)
          .with(
            evss_claim_id: claim_id,
            file_name: upload_data['name'],
            tracked_item_id: nil,
            document_type: upload_data['attachmentId']
          )
          .and_return(document_data)

        expect(client).to receive(:upload).with(attachment.file_data, document_data)
        subject.new.perform(upload_data, claim_id, auth_headers)
      end
    end

    context 'when file_data is nil' do
      let(:attachment) { double(:attachment, file_data: nil) }

      it 'raises an ArgumentError' do
        expect do
          subject.new.perform(upload_data, claim_id, auth_headers)
        end.to raise_error(
          ArgumentError,
          'supporting evidence attachment with guid d44d6f52-2e85-43d4-a5a3-1d9cb4e482a0 has no file data'
        )
      end
    end
  end
end
