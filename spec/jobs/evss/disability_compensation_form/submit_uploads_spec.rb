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
        confirmationCode: 'foo',
        name: 'bar',
        attachmentId: 'foobar'
      }
    end
    let(:client) { double(:client) }
    let(:attachment) { double(:attachment, file_data: nil) }
    let(:document_data) { double(:document_data) }

    it 'calls the documents service api with file body and document data' do
      allow(EVSS::DocumentsService)
        .to receive(:new)
        .and_return(client)
      allow(SupportingEvidenceAttachment)
        .to receive(:find_by)
        .and_return(attachment)
      allow(EVSSClaimDocument)
        .to receive(:new)
        .and_return(document_data)

      expect(client).to receive(:upload).with(attachment.file_data, document_data)
      subject.new.perform(upload_data, claim_id, auth_headers)
    end
  end
end
