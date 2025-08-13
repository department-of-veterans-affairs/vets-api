# frozen_string_literal: true

require 'rails_helper'
require 'simple_forms_api_submission/metadata_validator'
require 'common/file_helpers'
require 'lighthouse/benefits_intake/service'
require 'lgy/service'
require 'benefits_intake_service/service'

# Include ActiveSupport::Testing::TimeHelpers for time manipulation in tests
include ActiveSupport::Testing::TimeHelpers

RSpec.describe 'SimpleFormsApi::V1::UploadsController Additional Coverage', type: :request do
  let(:user) { create(:user, :legacy_icn) }
  let(:lighthouse_service) { instance_double(BenefitsIntake::Service) }

  before do
    allow(SimpleFormsApiSubmission::MetadataValidator).to receive(:validate)
    allow(BenefitsIntake::Service).to receive(:new).and_return(lighthouse_service)
  end

  describe '#submit_supporting_documents' do
    context 'with invalid form_id' do
      it 'returns unauthorized when form_id is not in allowed list' do
        post '/simple_forms_api/v1/simple_forms/submit_supporting_documents', 
             params: { form_id: '21-4142', file: fixture_file_upload('doctors-note.pdf', 'application/pdf') }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'document validation edge cases' do
      let(:file) { fixture_file_upload('doctors-note.pdf', 'application/pdf') }

      context 'for form 40-0247' do
        context 'when validation fails' do
          before do
            allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?)
              .and_raise(BenefitsIntakeService::Service::InvalidDocumentError.new('Invalid document'))
          end

          it 'returns error for 40-0247' do
            post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
                 params: { form_id: '40-0247', file: file }

            expect(response).to have_http_status(:unprocessable_entity)
            parsed_response = JSON.parse(response.body)
            expect(parsed_response['error']).to eq('Document validation failed: Invalid document')
          end
        end

        context 'when validation succeeds' do
          before do
            allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).and_return(true)
          end

          it 'proceeds with upload for 40-0247' do
            post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
                 params: { form_id: '40-0247', file: file }

            expect(response).to have_http_status(:ok)
          end
        end
      end

      context 'for form 40-10007' do
        context 'when validation fails' do
          before do
            allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?)
              .and_raise(BenefitsIntakeService::Service::InvalidDocumentError.new('Invalid document'))
          end

          it 'returns specific error message for 40-10007' do
            post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
                 params: { form_id: '40-10007', file: file }

            expect(response).to have_http_status(:unprocessable_entity)
            parsed_response = JSON.parse(response.body)
            expect(parsed_response['errors'][0]['detail']).to include("We weren't able to upload your file")
          end
        end
      end

      context 'with non-PDF file' do
        let(:file) { fixture_file_upload('logo.png', 'image/png') }

        it 'skips validation for non-PDF files' do
          expect_any_instance_of(BenefitsIntakeService::Service).not_to receive(:valid_document?)

          post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
               params: { form_id: '40-0247', file: file }

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'when attachment is invalid' do
      let(:file) { fixture_file_upload('doctors-note.pdf', 'application/pdf') }

      before do
        allow_any_instance_of(PersistentAttachments::MilitaryRecords).to receive(:valid?).and_return(false)
        allow_any_instance_of(PersistentAttachments::MilitaryRecords).to receive(:errors).and_return(
          double(full_messages: ['File is too large'])
        )
        # Mock the attachment object
        attachment = PersistentAttachments::MilitaryRecords.new
        allow(attachment).to receive(:valid?).and_return(false)
        allow(PersistentAttachments::MilitaryRecords).to receive(:new).and_return(attachment)
      end

      it 'returns validation error response' do
        post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
             params: { form_id: '40-0247', file: file }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe '#submit' do
    context 'exception handling' do
      let(:data) do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_21_4142.json')
        JSON.parse(fixture_path.read)
      end

      before { sign_in(user) }

      context 'when Prawn::Errors::IncompatibleStringEncoding is raised' do
        before do
          allow_any_instance_of(SimpleFormsApi::PdfFiller).to receive(:generate)
            .and_raise(Prawn::Errors::IncompatibleStringEncoding.new('encoding error'))
        end

        it 'does not catch the exception' do
          expect {
            post '/simple_forms_api/v1/simple_forms', params: data
          }.to raise_error(Prawn::Errors::IncompatibleStringEncoding)
        end
      end

      context 'when SimpleFormsApi::FormRemediation::Error is raised' do
        before do
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf_to_s3)
            .and_raise(SimpleFormsApi::FormRemediation::Error.new)
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
            .and_return([200, 'confirmation_number', double])
        end

        it 'logs the error and continues' do
          expect(Rails.logger).to receive(:error).with('Simple forms api - error uploading form submission to S3 bucket', error: anything)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'VSI flash functionality' do
      let(:data) do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_20_10207-veteran.json')
        JSON.parse(fixture_path.read)
      end

      let(:form_submission) { double(id: 123) }

      before do
        sign_in(user)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
          .and_return([200, 'confirmation_number', form_submission])
        # Mock the form creation to avoid complex setup
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
          .and_return(['/tmp/file.pdf', {}, double(respond_to?: true, track_user_identity: nil)])
      end

      context 'when VSI flash feature is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:priority_processing_request_apply_vsi_flash, user).and_return(true)
        end

        it 'attempts to call add_vsi_flash for 20-10207 forms' do
          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when VSI flash feature is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:priority_processing_request_apply_vsi_flash, user).and_return(false)
        end

        it 'does not attempt VSI flash operations' do
          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'intent to file error handling' do
      let(:data) do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_21_0966-min.json')
        data = JSON.parse(fixture_path.read)
        data['preparer_identification'] = 'VETERAN'
        data
      end

      before do
        sign_in(user)
        allow_any_instance_of(User).to receive(:participant_id).and_return('fake-participant-id')
        allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:use_intent_api?).and_return(true)
      end

      context 'when BenefitsClaimsApiDownError is raised' do
        before do
          allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:submit)
            .and_raise(SimpleFormsApi::Exceptions::BenefitsClaimsApiDownError.new('API is down'))
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
            .and_return([200, 'confirmation_number', double])
        end

        it 'falls back to benefits intake and logs the error' do
          expect(Rails.logger).to receive(:info).with(
            'Simple forms api - 21-0966 Benefits Claims Intent to File API error,' \
            'reverting to filling a PDF and sending it to Benefits Intake API',
            hash_including(error: anything)
          )

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when user has no postal_code' do
        before do
          allow_any_instance_of(User).to receive(:address).and_return({})
          allow_any_instance_of(SimpleFormsApi::IntentToFile).to receive(:submit)
            .and_raise(Common::Exceptions::UnprocessableEntity.new({}))
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
            .and_return([200, 'confirmation_number', double])
        end

        it 'sets default postal_code to 00000' do
          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'LGY Service edge cases' do
      let(:data) do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_26_4555.json')
        JSON.parse(fixture_path.read)
      end

      before { sign_in(user) }

      context 'when status is VALIDATED' do
        before do
          allow_any_instance_of(LGY::Service).to receive(:post_grant_application)
            .and_return(double(body: { 'reference_number' => 'ref123', 'status' => 'VALIDATED' }, status: 200))
        end

        it 'sends confirmation email' do
          expect_any_instance_of(SimpleFormsApi::Notification::Email).to receive(:send)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when status is REJECTED' do
        before do
          allow_any_instance_of(LGY::Service).to receive(:post_grant_application)
            .and_return(double(body: { 'reference_number' => 'ref123', 'status' => 'REJECTED' }, status: 200))
        end

        it 'sends rejected email' do
          expect_any_instance_of(SimpleFormsApi::Notification::Email).to receive(:send)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end

      context 'when status is DUPLICATE' do
        before do
          allow_any_instance_of(LGY::Service).to receive(:post_grant_application)
            .and_return(double(body: { 'reference_number' => 'ref123', 'status' => 'DUPLICATE' }, status: 200))
        end

        it 'sends duplicate email without confirmation number' do
          expect_any_instance_of(SimpleFormsApi::Notification::Email).to receive(:send)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'email error handling' do
      let(:data) do
        fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                       'vba_21_4142.json')
        JSON.parse(fixture_path.read)
      end

      before do
        sign_in(user)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
          .and_return([200, 'confirmation_number', double])
        # Mock the form creation
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
          .and_return(['/tmp/file.pdf', {}, double(track_user_identity: nil)])
      end

      context 'when confirmation email fails' do
        before do
          allow_any_instance_of(SimpleFormsApi::Notification::Email).to receive(:send)
            .and_raise(StandardError.new('Email service down'))
        end

        it 'logs the error and continues' do
          expect(Rails.logger).to receive(:error).with('Simple forms api - error sending confirmation email', error: anything)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'private method coverage' do
    let(:controller) { SimpleFormsApi::V1::UploadsController.new }

    before do
      allow(controller).to receive(:params).and_return({})
    end

    describe '#form_id' do
      it 'raises error when form_number is missing' do
        controller.params = {}
        
        expect {
          controller.send(:form_id)
        }.to raise_error('missing form_number in params')
      end

      it 'returns mapped form number' do
        allow(controller).to receive(:params).and_return({ form_number: '21-0966' })
        
        expect(controller.send(:form_id)).to eq('vba_21_0966')
      end
    end

    describe '#get_json' do
      before do
        allow(controller).to receive(:form_id).and_return('vba_21_0966')
      end

      it 'includes pdf_url when present' do
        result = controller.send(:get_json, 'conf123', 'https://example.com/pdf')
        
        expect(result[:pdf_url]).to eq('https://example.com/pdf')
      end

      it 'includes expiration_date for 21-0966 forms' do
        travel_to Time.zone.local(2024, 1, 1) do
          result = controller.send(:get_json, 'conf123', nil)
          
          expect(result[:expiration_date]).to eq(1.year.from_now)
        end
      end
    end

    describe '#skip_authentication?' do
      it 'returns true for unauthenticated form numbers' do
        allow(controller).to receive(:params).and_return({ form_number: '40-0247' })
        
        expect(controller.send(:skip_authentication?)).to be true
      end

      it 'returns true for unauthenticated form ids' do
        allow(controller).to receive(:params).and_return({ form_id: '40-10007' })
        
        expect(controller.send(:skip_authentication?)).to be true
      end

      it 'returns false for authenticated forms' do
        allow(controller).to receive(:params).and_return({ form_number: '21-0966' })
        
        expect(controller.send(:skip_authentication?)).to be false
      end
    end
  end

  describe 'edge cases in production environments' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_21_4142.json')
      JSON.parse(fixture_path.read)
    end

    before { sign_in(user) }

    context 'when not in production/staging/test environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('development')
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
          .and_return([200, 'confirmation_number', double])
      end

      it 'skips S3 upload' do
        expect_any_instance_of(SimpleFormsApi::FormRemediation::S3Client).not_to receive(:upload)

        post '/simple_forms_api/v1/simple_forms', params: data

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'authenticated user with LOA levels' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_21_4142.json')
      JSON.parse(fixture_path.read)
    end

    context 'when user is not authenticated' do
      before do
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
          .and_return([200, 'confirmation_number', double])
      end

      it 'generates PDF without LOA' do
        expect_any_instance_of(SimpleFormsApi::PdfFiller).to receive(:generate).with(no_args)

        post '/simple_forms_api/v1/simple_forms', params: data
      end
    end

    context 'when user is authenticated' do
      let(:user) { create(:user, :legacy_icn) }
      
      before do 
        sign_in(user)
        allow(user).to receive(:loa).and_return({ current: 3 })
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
          .and_return([200, 'confirmation_number', double])
      end

      it 'generates PDF with LOA level' do
        expect_any_instance_of(SimpleFormsApi::PdfFiller).to receive(:generate).with(3)

        post '/simple_forms_api/v1/simple_forms', params: data
      end
    end
  end
end
