# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::V1::UploadsController Edge Cases', type: :request do
  let(:user) { create(:user, :legacy_icn) }

  describe '#submit edge cases' do
    let(:data) do
      fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                     'vba_21_4142.json')
      JSON.parse(fixture_path.read)
    end

    context 'when S3 environment check' do
      before do
        sign_in(user)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
          .and_return([200, 'confirmation_number', double])
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
          .and_return(['/tmp/file.pdf', {}, double(track_user_identity: nil)])
      end

      context 'in development environment' do
        before do
          allow(Settings).to receive(:vsp_environment).and_return('development')
        end

        it 'skips S3 upload in non-production environments' do
          expect_any_instance_of(SimpleFormsApi::FormRemediation::S3Client).not_to receive(:upload)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'error handling paths' do
      before do
        sign_in(user)
      end

      context 'when send_confirmation_email_safely fails' do
        before do
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:upload_pdf)
            .and_return([200, 'confirmation_number', double])
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:get_file_paths_and_metadata)
            .and_return(['/tmp/file.pdf', {}, double(track_user_identity: nil)])
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:send_confirmation_email)
            .and_raise(StandardError.new('Email failed'))
        end

        it 'logs error and continues processing' do
          expect(Rails.logger).to receive(:error)
            .with('Simple forms api - error sending confirmation email', error: anything)

          post '/simple_forms_api/v1/simple_forms', params: data

          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'form-specific paths' do
      before { sign_in(user) }

      context 'when form_id is vba_21_0966 with VETERAN preparer' do
        let(:data) do
          fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json',
                                         'vba_21_0966.json')
          data = JSON.parse(fixture_path.read)
          data['preparer_identification'] = 'VETERAN'
          data
        end

        it 'calls populate_veteran_data when conditions are met' do
          expect_any_instance_of(SimpleFormsApi::VBA210966).to receive(:populate_veteran_data).with(user)

          post '/simple_forms_api/v1/simple_forms', params: data
        end
      end
    end
  end

  describe '#submit_supporting_documents edge cases' do
    context 'document validation scenarios' do
      let(:pdf_file) { fixture_file_upload('doctors-note.pdf', 'application/pdf') }

      context 'for allowed forms with PDF validation' do
        before do
          allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).and_return(true)
        end

        it 'validates PDF documents for form 40-0247' do
          expect_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).with(document: anything)

          post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
               params: { form_id: '40-0247', file: pdf_file }

          expect(response).to have_http_status(:ok)
        end

        it 'validates PDF documents for form 40-10007' do
          expect_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?).with(document: anything)

          post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
               params: { form_id: '40-10007', file: pdf_file }

          expect(response).to have_http_status(:ok)
        end
      end

      context 'validation failures' do
        let(:service_error) { BenefitsIntakeService::Service::InvalidDocumentError.new('Document invalid') }

        context 'for form 40-0247' do
          before do
            allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?)
              .and_raise(service_error)
          end

          it 'returns generic error message' do
            post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
                 params: { form_id: '40-0247', file: pdf_file }

            expect(response).to have_http_status(:unprocessable_entity)
            expect(JSON.parse(response.body)['error']).to include('Document validation failed')
          end
        end

        context 'for form 40-10007' do
          before do
            allow_any_instance_of(BenefitsIntakeService::Service).to receive(:valid_document?)
              .and_raise(service_error)
          end

          it 'returns user-friendly error message' do
            post '/simple_forms_api/v1/simple_forms/submit_supporting_documents',
                 params: { form_id: '40-10007', file: pdf_file }

            expect(response).to have_http_status(:unprocessable_entity)
            response_body = JSON.parse(response.body)
            expect(response_body['errors'][0]['detail']).to include("We weren't able to upload your file")
          end
        end
      end
    end
  end

  describe 'private method behaviors' do
    let(:controller) { SimpleFormsApi::V1::UploadsController.new }

    describe '#skip_authentication?' do
      it 'returns true for form_number in unauthenticated list' do
        allow(controller).to receive(:params).and_return({ form_number: '40-0247' })
        expect(controller.send(:skip_authentication?)).to be true
      end

      it 'returns true for form_id in unauthenticated list' do
        allow(controller).to receive(:params).and_return({ form_id: '21-10210' })
        expect(controller.send(:skip_authentication?)).to be true
      end

      it 'returns false for authenticated forms' do
        allow(controller).to receive(:params).and_return({ form_number: '21-4142' })
        expect(controller.send(:skip_authentication?)).to be false
      end
    end

    describe '#build_response' do
      it 'builds response with confirmation number and status' do
        result = controller.send(:build_response, 'conf123', 'https://example.com/pdf', 200)

        expect(result[:json][:confirmation_number]).to eq('conf123')
        expect(result[:status]).to eq(200)
      end

      it 'handles nil values gracefully' do
        result = controller.send(:build_response, nil, nil, 500)

        expect(result[:json][:confirmation_number]).to be_nil
        expect(result[:status]).to eq(500)
      end
    end

    describe '#validate_document_if_needed' do
      before do
        allow(controller).to receive(:params).and_return({ form_id: '40-0247' })
      end

      it 'returns true for non-PDF files' do
        result = controller.send(:validate_document_if_needed, '/path/to/file.txt')
        expect(result).to be true
      end

      it 'returns true for forms not in validation list' do
        allow(controller).to receive(:params).and_return({ form_id: '21-4142' })
        result = controller.send(:validate_document_if_needed, '/path/to/file.pdf')
        expect(result).to be true
      end
    end
  end

  describe 'response building edge cases' do
    let(:controller) { SimpleFormsApi::V1::UploadsController.new }

    describe '#get_json' do
      before do
        allow(controller).to receive(:form_id).and_return('vba_21_4142')
      end

      it 'includes pdf_url when provided' do
        result = controller.send(:get_json, 'conf123', 'https://example.com/pdf')
        expect(result[:pdf_url]).to eq('https://example.com/pdf')
      end

      it 'excludes pdf_url when not provided' do
        result = controller.send(:get_json, 'conf123', nil)
        expect(result).not_to have_key(:pdf_url)
      end

      it 'includes expiration_date for vba_21_0966 forms' do
        allow(controller).to receive(:form_id).and_return('vba_21_0966')
        result = controller.send(:get_json, 'conf123', nil)
        expect(result[:expiration_date]).to be_present
      end

      it 'excludes expiration_date for other forms' do
        result = controller.send(:get_json, 'conf123', nil)
        expect(result).not_to have_key(:expiration_date)
      end
    end
  end
end
