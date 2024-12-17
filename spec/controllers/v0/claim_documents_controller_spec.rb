# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::ClaimDocumentsController, type: :controller do
  let(:user) { create(:user) }
  let(:file) { fixture_file_upload('doctors-note.jpg') }
  let(:password) { 'password' }
  let(:params) { { form_id: '21P-527EZ', file: file, password: password } }
  let(:attachment) { build(:persistent_attachment_va_form, file_data: file.to_json) }
  let(:intake_service) { instance_double(BenefitsIntake::Service, valid_document?: true) }
  let(:monitor) { instance_double(ClaimDocuments::Monitor) }

  before do
    allow(controller).to receive_messages(current_user: user, uploads_monitor: monitor, intake_service:)
    allow(PersistentAttachment).to receive(:new).and_return(attachment)
    allow(monitor).to receive_messages(track_document_upload_attempt: nil, track_document_upload_success: nil,
                                       track_document_upload_failed: nil)
  end

  describe 'POST #create' do
    context 'when the document is valid' do
      it 'tracks the document upload attempt' do
        expect(monitor).to receive(:track_document_upload_attempt).once
        post :create, params: params
      end

      it 'saves the attachment' do
        expect(attachment).to receive(:save)
        post :create, params: params
      end

      it 'renders the attachment as JSON' do
        post :create, params: params
        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(PersistentAttachmentSerializer.new(attachment).to_json)
      end

      it 'tracks the document upload success' do
        expect(monitor).to receive(:track_document_upload_success).once
        post :create, params: params
      end
    end

    context 'when the document is invalid' do
      before do
        allow(attachment).to receive(:valid?).and_return(false)
      end

      it 'tracks the document upload failure' do
        expect(monitor).to receive(:track_document_upload_failed).once
        begin
          post :create, params: params
        rescue
          nil
        end
      end
    end
  end

  describe '#unlock_file' do
    before do
      allow(PdfForms).to receive(:new).and_return(double(call_pdftk: true))
    end

    it 'unlocks the file if it is a PDF and password is provided' do
      result = controller.send(:unlock_file, file, password)
      expect(result.tempfile.path).to eq(file.tempfile.path)
    end

    it 'returns the file if it is not a PDF or no password is provided' do
      result = controller.send(:unlock_file, file, nil)
      expect(result).to eq(file)
    end
  end
end
