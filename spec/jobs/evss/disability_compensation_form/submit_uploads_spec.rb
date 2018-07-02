# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe EVSS::DisabilityCompensationForm::SubmitUploads, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:claim_id) { 123_456_789 }
  let(:uploads) do
    [
      { guid: SecureRandom.uuid },
      { guid: SecureRandom.uuid },
      { guid: SecureRandom.uuid },
      { guid: SecureRandom.uuid }
    ]
  end

  subject { described_class }

  describe '.start' do
    before(:each) do
      allow(subject).to receive(:get_uploads).and_return(uploads)
    end

    context 'with four uploads' do
      it 'queues four submit upload jobs' do
        expect do
          subject.start(user, claim_id)
        end.to change(subject.jobs, :size).by(4)
      end
    end

    context 'with no uploads' do
      let(:uploads) { [] }

      it 'queues no submit upload jobs' do
        expect do
          subject.start(user, claim_id)
        end.to_not change(subject.jobs, :size)
      end
    end
  end

  describe 'perform' do
    let(:upload_data) do
      {
        guid: 'foo',
        file_name: 'bar',
        doctype: 'foobar'
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
      subject.perform(upload_data, claim_id, user)
    end
  end

  describe 'get_uploads' do
    let(:in_progress_form) { double(:in_progress_form, uploads: uploads) }

    it 'returns the claim id of a submission' do
      allow(InProgressDisabilityCompensationForm)
        .to receive(:form_for_user)
        .and_return(in_progress_form)

      expect(subject.get_uploads(user.uuid)).to eq uploads
    end
  end
end
