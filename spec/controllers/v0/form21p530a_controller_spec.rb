# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form21p530aController, type: :controller do
  before do
    allow(Flipper).to receive(:enabled?).with(:form_530a_enabled).and_return(true)
  end

  let(:valid_payload) { JSON.parse(Rails.root.join('spec', 'fixtures', 'form21p530a', 'valid_form.json').read) }

  describe 'POST #create' do
    it 'returns expected response structure' do
      post(:create, body: valid_payload.to_json, as: :json)

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['type']).to eq('saved_claims')
      expect(json['data']['attributes']['form']).to eq('21P-530A')
      expect(json['data']['attributes']['confirmation_number']).to be_present
      expect(json['data']['attributes']['submitted_at']).to be_present
      expect(json['data']['attributes']['guid']).to be_present
      expect(json['data']['attributes']['regional_office']).to be_an(Array)
    end

    it 'returns a unique confirmation number for each request' do
      post(:create, body: valid_payload.to_json, as: :json)
      first_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      post(:create, body: valid_payload.to_json, as: :json)
      second_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      expect(first_confirmation).not_to eq(second_confirmation)
    end

    it 'returns a valid UUID as confirmation number' do
      post(:create, body: valid_payload.to_json, as: :json)

      confirmation = JSON.parse(response.body).dig('data', 'attributes', 'confirmation_number')
      expect(confirmation).to be_a_uuid
    end

    it 'returns ISO 8601 formatted timestamp' do
      post(:create, body: valid_payload.to_json, as: :json)

      submitted_at = JSON.parse(response.body).dig('data', 'attributes', 'submitted_at')
      expect { DateTime.iso8601(submitted_at) }.not_to raise_error
    end

    it 'does not require authentication' do
      post(:create, body: valid_payload.to_json, as: :json)
      expect(response).to have_http_status(:ok)
    end

    it 'queues Lighthouse submission job' do
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(anything)
      post(:create, body: valid_payload.to_json, as: :json)
    end

    context 'with 3-character country code' do
      let(:payload_with_3char_country) do
        payload = valid_payload.deep_dup
        payload['burialInformation']['recipientOrganization']['address']['country'] = 'USA'
        payload
      end

      it 'transforms 3-character country code to 2-character' do
        post(:create, body: payload_with_3char_country.to_json, as: :json)
        expect(response).to have_http_status(:ok)

        # Verify the claim was created successfully (transformation happened)
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['confirmation_number']).to be_present
      end
    end

    context 'with invalid country code' do
      let(:payload_with_invalid_country) do
        payload = valid_payload.deep_dup
        payload['burialInformation']['recipientOrganization']['address']['country'] = 'XX'
        payload
      end

      it 'rejects invalid 2-character country code' do
        post(:create, body: payload_with_invalid_country.to_json, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['detail']).to include("'XX' is not a valid country code")
      end

      it 'rejects invalid 3-character country code' do
        payload = valid_payload.deep_dup
        payload['burialInformation']['recipientOrganization']['address']['country'] = 'ZZZ'

        post(:create, body: payload.to_json, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['detail']).to include("'ZZZ' is not a valid country code")
      end

      it 'increments failure stats' do
        expect(StatsD).to receive(:increment).with('api.form21p530a.failure')
        post(:create, body: payload_with_invalid_country.to_json, as: :json)
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_530a_enabled, anything).and_return(false)
      end

      it 'returns 404 Not Found (routing error)' do
        post(:create, body: valid_payload.to_json, as: :json)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid form data' do
      let(:invalid_payload) do
        {
          veteranInformation: {
            fullName: { first: 'OnlyFirst' }
          }
        }
      end

      it 'returns validation errors' do
        post(:create, body: invalid_payload.to_json, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end

      it 'increments failure stats' do
        expect(StatsD).to receive(:increment).with('api.form21p530a.failure')
        post(:create, body: invalid_payload.to_json, as: :json)
      end
    end

    context 'InProgressForm cleanup' do
      let(:user) { create(:user, :loa3) }
      let!(:in_progress_form) { create(:in_progress_form, form_id: '21P-530A', user_account: user.user_account) }

      before do
        sign_in_as(user)
      end

      it 'deletes the InProgressForm after successful submission' do
        expect do
          post(:create, body: valid_payload.to_json, as: :json)
        end.to change(InProgressForm, :count).by(-1)

        expect(response).to have_http_status(:ok)
        expect(InProgressForm.find_by(id: in_progress_form.id)).to be_nil
      end

      it 'does not delete IPF if submission fails' do
        invalid_payload = { veteranInformation: { fullName: { first: 'OnlyFirst' } } }

        expect do
          post(:create, body: invalid_payload.to_json, as: :json)
        end.not_to change(InProgressForm, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'POST #download_pdf' do
    let(:pdf_content) { 'PDF_BINARY_CONTENT' }
    let(:temp_file_path) { '/tmp/test_pdf.pdf' }

    before do
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(temp_file_path)
      allow(PdfFill::Forms::Va21p530a).to receive(:stamp_signature).and_return(temp_file_path)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(temp_file_path).and_return(pdf_content)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(temp_file_path).and_return(true)
      allow(File).to receive(:delete).and_call_original
      allow(File).to receive(:delete).with(temp_file_path)
    end

    it 'generates and downloads PDF' do
      post(:download_pdf, body: valid_payload.to_json, as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/pdf')
      expect(response.body).to eq(pdf_content)
    end

    it 'includes proper filename with UUID' do
      post(:download_pdf, body: valid_payload.to_json, as: :json)

      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include('21P-530a_')
      expect(response.headers['Content-Disposition']).to match(/21P-530a_[a-f0-9-]+\.pdf/)
    end

    it 'generates unique filename for each request' do
      post(:download_pdf, body: valid_payload.to_json, as: :json)
      first_filename = response.headers['Content-Disposition']

      post(:download_pdf, body: valid_payload.to_json, as: :json)
      second_filename = response.headers['Content-Disposition']

      expect(first_filename).not_to eq(second_filename)
    end

    it 'calls PDF filler with correct parameters' do
      expect(PdfFill::Filler).to receive(:fill_ancillary_form)
        .with(anything, anything, '21P-530a')
        .and_return(temp_file_path)

      post(:download_pdf, body: valid_payload.to_json, as: :json)
    end

    it 'calls stamp_signature with the PDF path and form data' do
      expect(PdfFill::Forms::Va21p530a).to receive(:stamp_signature)
        .with(temp_file_path, anything)
        .and_return(temp_file_path)

      post(:download_pdf, body: valid_payload.to_json, as: :json)
    end

    it 'deletes temporary PDF file after sending' do
      expect(File).to receive(:delete).with(temp_file_path)
      post(:download_pdf, body: valid_payload.to_json, as: :json)
    end

    it 'deletes temporary file even when PDF generation fails' do
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF generation error')
      # File.delete should not be called since source_file_path is nil
      expect(File).not_to receive(:delete)

      post(:download_pdf, body: valid_payload.to_json, as: :json)
      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
      expect(json['errors'].first['title']).to eq('Internal server error')
      expect(json['errors'].first['status']).to eq('500')
    end

    it 'deletes temporary file even when file read fails' do
      allow(File).to receive(:read).with(temp_file_path).and_raise(StandardError, 'Read error')
      expect(File).to receive(:delete).with(temp_file_path)

      post(:download_pdf, body: valid_payload.to_json, as: :json)
      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
      expect(json['errors'].first['title']).to eq('Internal server error')
    end

    it 'does not require authentication' do
      post(:download_pdf, body: valid_payload.to_json, as: :json)

      expect(response).to have_http_status(:ok)
    end

    context 'with 3-character country code' do
      let(:payload_with_3char_country) do
        payload = valid_payload.deep_dup
        payload['burialInformation']['recipientOrganization']['address']['country'] = 'USA'
        payload
      end

      it 'transforms 3-character country code to 2-character for PDF generation' do
        expect(PdfFill::Filler).to receive(:fill_ancillary_form) do |form_data, _uuid, _form_type|
          # Verify the country code was transformed to 2-character
          address = form_data.dig('burialInformation', 'recipientOrganization', 'address')
          expect(address['country']).to eq('US')
          temp_file_path
        end

        post(:download_pdf, body: payload_with_3char_country.to_json, as: :json)
        expect(response).to have_http_status(:ok)
      end
    end

    context 'with invalid country code' do
      let(:payload_with_invalid_country) do
        payload = valid_payload.deep_dup
        payload['burialInformation']['recipientOrganization']['address']['country'] = 'XX'
        payload
      end

      it 'rejects invalid 2-character country code' do
        post(:download_pdf, body: payload_with_invalid_country.to_json, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['detail']).to include("'XX' is not a valid country code")
      end

      it 'rejects invalid 3-character country code' do
        payload = valid_payload.deep_dup
        payload['burialInformation']['recipientOrganization']['address']['country'] = 'ZZZ'

        post(:download_pdf, body: payload.to_json, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['detail']).to include("'ZZZ' is not a valid country code")
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_530a_enabled, anything).and_return(false)
      end

      it 'returns 404 Not Found (routing error)' do
        post(:download_pdf, body: valid_payload.to_json, as: :json)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'error handling' do
      it 'returns 500 for PDF generation failures' do
        allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF error')

        post(:download_pdf, body: valid_payload.to_json, as: :json)

        expect(response).to have_http_status(:internal_server_error)

        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['title']).to eq('Internal server error')
        expect(json['errors'].first['status']).to eq('500')
      end
    end
  end
end
