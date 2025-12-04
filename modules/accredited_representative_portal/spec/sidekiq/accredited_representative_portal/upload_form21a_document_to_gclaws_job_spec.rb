# frozen_string_literal: true

require 'rails_helper'
require_relative '../../spec_helper'

RSpec.describe AccreditedRepresentativePortal::UploadForm21aDocumentToGCLAWSJob, type: :job do
  let(:form21a_attachment_guid) { SecureRandom.uuid }
  let(:application_id) { '12345' }
  let(:document_type) { 1 }
  let(:original_file_name) { 'test_document.pdf' }
  let(:content_type) { 'application/pdf' }

  let(:form21a_attachment) do
    create(:form_attachment, guid: form21a_attachment_guid, type: 'Form21aAttachment')
  end

  # Mock file needs `delete` for FormAttachment's before_destroy callback
  let(:mock_file) { double('file', read: 'file contents', delete: true) }

  let(:document_upload_url) { 'http://localhost:5000/api/v1/documents' }

  before do
    allow(Settings.ogc.form21a_service_url).to receive_messages(
      document_upload_url:,
      api_key: 'test_api_key'
    )
  end

  describe '#perform' do
    subject(:perform_job) do
      described_class.new.perform(
        form21a_attachment_guid,
        application_id,
        document_type,
        original_file_name,
        content_type
      )
    end

    context 'when attachment exists and upload succeeds' do
      before do
        form21a_attachment
        allow_any_instance_of(FormAttachment).to receive(:get_file).and_return(mock_file)
      end

      it 'uploads the document to GCLAWS and deletes the attachment' do
        stub_request(:post, document_upload_url)
          .with(
            headers: {
              'Content-Type' => 'application/json',
              'x-api-key' => 'test_api_key'
            }
          )
          .to_return(status: 200, body: { success: true }.to_json)

        expect { perform_job }.to change(FormAttachment, :count).by(-1)
      end

      it 'sends the correct payload to GCLAWS' do
        expected_body = {
          ApplicationId: application_id,
          DocumentType: document_type,
          FileType: 1, # PDF
          OriginalFileName: original_file_name,
          FileDetails: Base64.strict_encode64('file contents')
        }

        stub = stub_request(:post, document_upload_url)
               .with(body: expected_body.to_json)
               .to_return(status: 200, body: { success: true }.to_json)

        perform_job

        expect(stub).to have_been_requested
      end

      it 'logs success messages' do
        stub_request(:post, document_upload_url)
          .to_return(status: 200, body: { success: true }.to_json)

        expect(Rails.logger).to receive(:info).with(/Starting upload/)
        expect(Rails.logger).to receive(:info).with(/Successfully uploaded/)
        expect(Rails.logger).to receive(:info).with(/Deleted Form21aAttachment/)

        perform_job
      end
    end

    context 'when attachment does not exist' do
      it 'logs an error and returns early' do
        expect(Rails.logger).to receive(:info).with(/Starting upload/)
        expect(Rails.logger).to receive(:error).with(/Form21aAttachment not found/)

        result = perform_job

        expect(result).to be_nil
      end

      it 'does not make an HTTP request' do
        stub = stub_request(:post, document_upload_url)

        perform_job

        expect(stub).not_to have_been_requested
      end
    end

    context 'when file retrieval from S3 fails' do
      before do
        form21a_attachment
        allow_any_instance_of(FormAttachment).to receive(:get_file)
          .and_raise(StandardError, 'S3 connection failed')
      end

      it 'logs an error and raises the exception for retry' do
        expect(Rails.logger).to receive(:info).with(/Starting upload/)
        expect(Rails.logger).to receive(:error).with(/Failed to retrieve file from S3/)

        expect { perform_job }.to raise_error(StandardError, 'S3 connection failed')
      end
    end

    context 'when GCLAWS API returns an error' do
      before do
        form21a_attachment
        allow_any_instance_of(FormAttachment).to receive(:get_file).and_return(mock_file)
      end

      it 'logs the error and raises for retry' do
        stub_request(:post, document_upload_url)
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json)

        expect(Rails.logger).to receive(:info).with(/Starting upload/)
        expect(Rails.logger).to receive(:error).with(/GCLAWS API error/)

        expect { perform_job }.to raise_error(/GCLAWS Document API returned 500/)
      end

      it 'does not delete the attachment on failure' do
        stub_request(:post, document_upload_url)
          .to_return(status: 500, body: { error: 'Internal Server Error' }.to_json)

        expect do
          perform_job
        rescue
          nil
        end.not_to change(FormAttachment, :count)
      end
    end

    context 'when attachment deletion fails after successful upload' do
      before do
        form21a_attachment
        allow_any_instance_of(FormAttachment).to receive(:get_file).and_return(mock_file)
        allow_any_instance_of(FormAttachment).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed)
      end

      it 'logs the deletion error but does not raise' do
        stub_request(:post, document_upload_url)
          .to_return(status: 200, body: { success: true }.to_json)

        expect(Rails.logger).to receive(:info).with(/Starting upload/)
        expect(Rails.logger).to receive(:info).with(/Successfully uploaded/)
        expect(Rails.logger).to receive(:error).with(/Failed to delete Form21aAttachment/)

        # Should not raise - upload succeeded
        expect { perform_job }.not_to raise_error
      end
    end

    context 'with DOCX file type' do
      let(:content_type) { 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' }
      let(:original_file_name) { 'test_document.docx' }

      before do
        form21a_attachment
        allow_any_instance_of(FormAttachment).to receive(:get_file).and_return(mock_file)
      end

      it 'sends FileType 2 for DOCX files' do
        stub = stub_request(:post, document_upload_url)
               .with(body: hash_including(FileType: 2))
               .to_return(status: 200, body: { success: true }.to_json)

        perform_job

        expect(stub).to have_been_requested
      end
    end
  end

  describe '.sidekiq_retries_exhausted' do
    it 'logs an error when all retries are exhausted' do
      job = { 'args' => [form21a_attachment_guid, application_id, document_type, original_file_name, content_type] }
      exception = StandardError.new('Connection failed')

      expect(Rails.logger).to receive(:error).with(
        /All retries exhausted for Form21aAttachment guid=#{form21a_attachment_guid}/
      )

      described_class.sidekiq_retries_exhausted_block.call(job, exception)
    end
  end
end
