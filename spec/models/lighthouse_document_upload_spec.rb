# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LighthouseDocumentUpload do
  context 'for a new record' do
    context 'with valid attributes' do
      it 'is valid with a valid document_type' do
        ['BDD Instructions', 'Form 0781', 'Form 0781a', 'Veteran Upload'].each do |document_type|
          expect(build(:lighthouse_document_upload, document_type:)).to be_valid
        end
      end

      context 'with a document type that is not Veteran Upload' do
        it 'is valid without a form_attachment_id' do
          expect(build(:lighthouse_document_upload, document_type: 'BDD Instructions', form_attachment_id: nil))
            .to be_valid
        end
      end
    end

    context 'with invalid attributes' do
      it 'is invalid without a form526_submission_id' do
        expect(build(:lighthouse_document_upload, form526_submission_id: nil)).not_to be_valid
      end

      it 'is invalid without a lighthouse_document_request_id' do
        expect(build(:lighthouse_document_upload, lighthouse_document_request_id: nil)).not_to be_valid
      end

      it 'is invalid without a document_type' do
        expect(build(:lighthouse_document_upload, document_type: nil)).not_to be_valid
      end

      it 'is invalid without a valid document_type' do
        expect(build(:lighthouse_document_upload, document_type: 'Grocery Shopping List')).not_to be_valid
      end

      context 'with a document_type of Veteran Upload' do
        it 'is invalid without a form_attachment_id' do
          expect(build(:lighthouse_document_upload, document_type: 'Veteran Upload', form_attachment_id: nil))
            .not_to be_valid
        end
      end
    end
  end
end
