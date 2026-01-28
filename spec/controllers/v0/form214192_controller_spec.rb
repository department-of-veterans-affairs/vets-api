# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form214192Controller, type: :controller do
  before do
    allow(Flipper).to receive(:enabled?).with(:form_4192_enabled).and_return(true)
  end

  let(:valid_payload) { JSON.parse(Rails.root.join('spec', 'fixtures', 'form214192', 'valid_form.json').read) }

  let(:form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'pdf_fill', '21-4192', 'simple.json').read)
  end

  describe 'POST #create' do
    it 'returns expected response structure' do
      post(:create, body: valid_payload.to_json, as: :json)

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['data']['type']).to eq('saved_claims')
      expect(json['data']['attributes']['form']).to eq('21-4192')
      expect(json['data']['attributes']['confirmation_number']).to be_present
      expect(json['data']['attributes']['submitted_at']).to be_present
      expect(json['data']['attributes']['guid']).to be_present
      expect(json['data']['attributes']['regional_office']).to eq([])
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

    context 'with expired access token' do
      let(:access_token_object) { create(:access_token, expiration_time: 1.day.ago) }
      let(:access_token_cookie) { SignIn::AccessTokenJwtEncoder.new(access_token: access_token_object).perform }

      before do
        cookies[SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME] = access_token_cookie
      end

      it 'allows form submission despite expired token' do
        post(:create, body: valid_payload.to_json, as: :json)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['type']).to eq('saved_claims')
        expect(json['data']['attributes']['confirmation_number']).to be_present
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_4192_enabled, anything).and_return(false)
      end

      it 'returns 404 Not Found (routing error)' do
        post(:create, body: valid_payload.to_json, as: :json)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'InProgressForm cleanup' do
      let(:user) { create(:user, :loa3) }
      let!(:in_progress_form) { create(:in_progress_form, form_id: '21-4192', user_account: user.user_account) }

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
      allow(PdfFill::Forms::Va214192).to receive(:stamp_signature).and_return(temp_file_path)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(temp_file_path).and_return(pdf_content)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(temp_file_path).and_return(true)
      allow(File).to receive(:delete).and_call_original
      allow(File).to receive(:delete).with(temp_file_path)
    end

    it 'generates and downloads PDF' do
      post(:download_pdf, body: form_data.to_json, as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/pdf')
      expect(response.body).to eq(pdf_content)
    end

    it 'includes proper filename with UUID' do
      post(:download_pdf, body: form_data.to_json, as: :json)

      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include('21-4192_')
      expect(response.headers['Content-Disposition']).to match(/21-4192_[a-f0-9-]+\.pdf/)
    end

    it 'generates unique filename for each request' do
      post(:download_pdf, body: form_data.to_json, as: :json)
      first_filename = response.headers['Content-Disposition']

      post(:download_pdf, body: form_data.to_json, as: :json)
      second_filename = response.headers['Content-Disposition']

      expect(first_filename).not_to eq(second_filename)
    end

    it 'calls PDF filler with correct parameters' do
      expect(PdfFill::Filler).to receive(:fill_ancillary_form)
        .with(hash_including('employmentInformation' => hash_including('employerName' => 'Acme Corporation')),
              anything,
              '21-4192')
        .and_return(temp_file_path)

      post(:download_pdf, body: form_data.to_json, as: :json)
    end

    it 'calls stamp_signature with the PDF path and form data' do
      expect(PdfFill::Forms::Va214192).to receive(:stamp_signature)
        .with(temp_file_path, hash_including('employmentInformation' => anything))
        .and_return(temp_file_path)

      post(:download_pdf, body: form_data.to_json, as: :json)
    end

    it 'deletes temporary PDF file after sending' do
      expect(File).to receive(:delete).with(temp_file_path)
      post(:download_pdf, body: form_data.to_json, as: :json)
    end

    it 'deletes temporary file even when PDF generation fails' do
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF generation error')
      # File.delete should not be called since source_file_path is nil
      expect(File).not_to receive(:delete)

      post(:download_pdf, body: form_data.to_json, as: :json)
      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
      expect(json['errors'].first['title']).to eq('PDF Generation Failed')
      expect(json['errors'].first['status']).to eq('500')
    end

    it 'deletes temporary file even when file read fails' do
      allow(File).to receive(:read).with(temp_file_path).and_raise(StandardError, 'Read error')
      expect(File).to receive(:delete).with(temp_file_path)

      post(:download_pdf, body: form_data.to_json, as: :json)
      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
      expect(json['errors'].first['title']).to eq('PDF Generation Failed')
    end

    it 'does not require authentication' do
      post(:download_pdf, body: form_data.to_json, as: :json)

      expect(response).to have_http_status(:ok)
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_4192_enabled, anything).and_return(false)
      end

      it 'returns 404 Not Found (routing error)' do
        post(:download_pdf, body: form_data.to_json, as: :json)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'error handling' do
      it 'returns 500 for PDF generation failures' do
        allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF error')

        post(:download_pdf, body: form_data.to_json, as: :json)

        expect(response).to have_http_status(:internal_server_error)

        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['title']).to eq('PDF Generation Failed')
        expect(json['errors'].first['status']).to eq('500')
      end
    end

    context 'with 30-character street2 address' do
      let(:payload_with_max_street2) do
        payload = form_data.deep_dup
        payload['employmentInformation']['employerAddress']['street2'] = 'B' * 30
        payload
      end

      it 'accepts street2 with exactly 30 characters' do
        post(:download_pdf, body: payload_with_max_street2.to_json, as: :json)

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/pdf')
      end
    end
  end

  describe 'address field validation' do
    context 'with extended street2 values' do
      let(:payload_with_long_street2) do
        payload = valid_payload.deep_dup
        # Set street2 to a value longer than old 5-char limit but within new 30-char limit
        payload['veteranInformation']['address']['street2'] = 'Apartment Suite 10B'
        payload['employmentInformation']['employerAddress']['street2'] = 'Building A, Floor 3'
        payload
      end

      it 'accepts street2 values up to 30 characters for form submission' do
        post(:create, body: payload_with_long_street2.to_json, as: :json)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['data']['attributes']['confirmation_number']).to be_present
      end

      it 'accepts street2 values up to 30 characters for PDF generation' do
        post(:download_pdf, body: payload_with_long_street2.to_json, as: :json)

        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/pdf')
      end
    end

    context 'with street2 values exceeding 30 characters' do
      let(:payload_with_too_long_street2) do
        payload = valid_payload.deep_dup
        # Set street2 to 31 characters (exceeds new maximum)
        payload['veteranInformation']['address']['street2'] = 'A' * 31
        payload
      end

      it 'rejects street2 values exceeding 30 characters for form submission' do
        post(:create, body: payload_with_too_long_street2.to_json, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end
  end
end
