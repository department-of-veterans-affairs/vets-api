# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/metadata_validator'

RSpec.describe SimpleFormsApi::ScannedFormUploadService do
  subject(:service) do
    described_class.new(
      params:,
      current_user: user,
      lighthouse_service:
    )
  end

  let(:user) { build(:user, :loa3) }
  let(:form_number) { '21-0779' }
  let(:lighthouse_service) { instance_double(BenefitsIntake::Service) }
  let(:confirmation_code) { 'test-confirmation-code' }
  let(:main_attachment) { instance_double(PersistentAttachment, guid: confirmation_code) }
  let(:pdf_path) { '/path/to/file.pdf' }
  let(:upload_location) { 'https://example.com/upload' }
  let(:upload_uuid) { 'uuid-123' }
  let(:upload_response) { double(status: 200) }

  let(:params) do
    {
      form_number:,
      confirmation_code:,
      form_data: {
        full_name: { first: 'John', last: 'Doe' },
        id_number: { ssn: '123-45-6789' },
        postal_code: '12345',
        email: 'john.doe@example.com'
      },
      supporting_documents: []
    }
  end

  before do
    allow(PersistentAttachment).to receive(:find_by!).with(guid: confirmation_code).and_return(main_attachment)
    allow(main_attachment).to receive(:to_pdf).and_return(double(to_s: pdf_path))
    allow(File).to receive(:size).with(pdf_path).and_return(1024 * 1024) # 1 MB
    allow(lighthouse_service).to receive_messages(request_upload: [upload_location, upload_uuid],
                                                  perform_upload: upload_response)
  end

  describe '#upload_with_supporting_documents' do
    let(:pdf_stamper) { instance_double(SimpleFormsApi::PdfStamper) }
    let(:metadata) { { 'veteranFirstName' => 'John', 'veteranLastName' => 'Doe' } }

    before do
      allow(SimpleFormsApi::PdfStamper).to receive(:new).and_return(pdf_stamper)
      allow(pdf_stamper).to receive(:stamp_pdf)
      allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate).and_return(metadata)
      allow(FormSubmission).to receive(:create).and_return(double)
      allow(FormSubmissionAttempt).to receive(:create)
      allow(Rails.logger).to receive(:info)
      allow(Datadog::Tracing).to receive(:active_trace).and_return(double(set_tag: true))
    end

    context 'when there are no supporting documents' do
      it 'uploads only the main document' do
        status, confirmation_number = service.upload_with_supporting_documents

        expect(status).to eq(200)
        expect(confirmation_number).to eq(upload_uuid)
        expect(lighthouse_service).to have_received(:perform_upload).with(
          metadata: metadata.to_json,
          document: pdf_path,
          upload_url: upload_location,
          attachments: []
        )
      end

      it 'stamps the PDF' do
        service.upload_with_supporting_documents

        expect(SimpleFormsApi::PdfStamper).to have_received(:new).with(
          stamped_template_path: pdf_path,
          current_loa: user.loa[:current],
          form_number:,
          timestamp: instance_of(ActiveSupport::TimeWithZone)
        )
        expect(pdf_stamper).to have_received(:stamp_pdf)
      end

      it 'creates form submission with flat data structure preserving form_data fields at top level' do
        form_submission = double
        expected_form_data = params[:form_data].to_h.merge(
          confirmation_code: params[:confirmation_code],
          supporting_documents: []
        ).to_json

        expect(FormSubmission).to receive(:create).with(
          form_type: form_number,
          form_data: expected_form_data,
          user_account: user.user_account
        ).and_return(form_submission)

        expect(FormSubmissionAttempt).to receive(:create).with(
          form_submission:,
          benefits_intake_uuid: upload_uuid
        )

        service.upload_with_supporting_documents
      end

      it 'logs the upload result' do
        service.upload_with_supporting_documents

        expect(Rails.logger).to have_received(:info).with(
          'Simple forms api - scanned form uploaded',
          hash_including(
            form_number:,
            status: 200,
            confirmation_number: upload_uuid,
            file_size: instance_of(Float)
          )
        )
      end
    end

    context 'when there are supporting documents' do
      let(:supporting_attachment1) { instance_double(PersistentAttachment, guid: 'support-1') }
      let(:supporting_attachment2) { instance_double(PersistentAttachment, guid: 'support-2') }
      let(:support_path1) { '/path/to/support1.pdf' }
      let(:support_path2) { '/path/to/support2.pdf' }

      let(:params) do
        {
          form_number:,
          confirmation_code:,
          form_data: {
            full_name: { first: 'John', last: 'Doe' },
            id_number: { ssn: '123-45-6789' },
            postal_code: '12345',
            email: 'john.doe@example.com'
          },
          supporting_documents: [
            { confirmation_code: 'support-1' },
            { confirmation_code: 'support-2' }
          ]
        }
      end

      before do
        allow(PersistentAttachment).to receive(:where)
          .with(guid: %w[support-1 support-2])
          .and_return([supporting_attachment1, supporting_attachment2])
        allow(supporting_attachment1).to receive(:to_pdf).and_return(double(to_s: support_path1))
        allow(supporting_attachment2).to receive(:to_pdf).and_return(double(to_s: support_path2))
      end

      it 'uploads main document with supporting attachments' do
        status, confirmation_number = service.upload_with_supporting_documents

        expect(status).to eq(200)
        expect(confirmation_number).to eq(upload_uuid)
        expect(lighthouse_service).to have_received(:perform_upload).with(
          metadata: metadata.to_json,
          document: pdf_path,
          upload_url: upload_location,
          attachments: [support_path1, support_path2]
        )
      end

      it 'creates form submission with flat data structure including supporting document confirmation codes' do
        form_submission = double
        expected_form_data = params[:form_data].to_h.merge(
          confirmation_code: params[:confirmation_code],
          supporting_documents: params[:supporting_documents]
        ).to_json

        expect(FormSubmission).to receive(:create).with(
          form_type: form_number,
          form_data: expected_form_data,
          user_account: user.user_account
        ).and_return(form_submission)

        expect(FormSubmissionAttempt).to receive(:create).with(
          form_submission:,
          benefits_intake_uuid: upload_uuid
        )

        service.upload_with_supporting_documents
      end
    end

    context 'when main attachment is not found' do
      before do
        allow(PersistentAttachment).to receive(:find_by!)
          .with(guid: confirmation_code)
          .and_raise(ActiveRecord::RecordNotFound)
      end

      it 'raises a RecordNotFound exception' do
        expect do
          service.upload_with_supporting_documents
        end.to raise_error(Common::Exceptions::RecordNotFound)
      end
    end

    context 'when metadata validation is called' do
      it 'builds correct metadata from params' do
        service.upload_with_supporting_documents

        expect(SimpleFormsApiSubmission::MetadataValidator).to have_received(:validate).with(
          hash_including(
            'veteranFirstName' => 'John',
            'veteranLastName' => 'Doe',
            'fileNumber' => '123-45-6789',
            'zipCode' => '12345',
            'source' => 'VA Platform Digital Forms',
            'docType' => form_number,
            'businessLine' => 'CMP'
          )
        )
      end
    end

    context 'when using VA file number instead of SSN' do
      let(:params) do
        {
          form_number:,
          confirmation_code:,
          form_data: {
            full_name: { first: 'John', last: 'Doe' },
            id_number: { va_file_number: 'VA123456' },
            postal_code: '12345',
            email: 'john.doe@example.com'
          },
          supporting_documents: []
        }
      end

      it 'uses VA file number in metadata' do
        service.upload_with_supporting_documents

        expect(SimpleFormsApiSubmission::MetadataValidator).to have_received(:validate).with(
          hash_including('fileNumber' => 'VA123456')
        )
      end
    end

    context 'when Lighthouse upload raises a client error' do
      before do
        allow(lighthouse_service).to receive(:perform_upload)
          .and_raise(Common::Client::Errors::ClientError.new('Boom', 502))
      end

      it 'raises an UploadError with a user-friendly message' do
        expect do
          service.upload_with_supporting_documents
        rescue SimpleFormsApi::ScannedFormUploadService::UploadError => e
          expect(e.errors.first[:title]).to eq('Submission failed')
          expect(e.http_status).to eq(502)
          raise
        end.to raise_error(SimpleFormsApi::ScannedFormUploadService::UploadError)
      end
    end
  end
end
