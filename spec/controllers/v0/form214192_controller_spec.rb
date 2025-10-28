# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form214192Controller, type: :controller do
  let(:form_data) do
    JSON.parse(Rails.root.join('spec', 'fixtures', 'pdf_fill', '21-4192', 'simple.json').read)
  end

  describe 'POST #create' do
    it 'returns expected response structure' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      post(:create, params: { form214192: form_data })

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
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      post(:create, params: { form214192: form_data })
      first_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      post(:create, params: { form214192: form_data })
      second_confirmation = JSON.parse(response.body)['data']['attributes']['confirmation_number']

      expect(first_confirmation).not_to eq(second_confirmation)
    end

    it 'returns a valid UUID as confirmation number' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      post(:create, params: { form214192: form_data })

      json = JSON.parse(response.body)
      confirmation = json['data']['attributes']['confirmation_number']

      expect(confirmation).to be_a_uuid
    end

    it 'returns ISO 8601 formatted timestamp' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      post(:create, params: { form214192: form_data })

      json = JSON.parse(response.body)
      submitted_at = json['data']['attributes']['submitted_at']

      expect { DateTime.iso8601(submitted_at) }.not_to raise_error
    end

    it 'does not require authentication' do
      form_data = {
        veteranInformation: { fullName: { first: 'John', last: 'Doe' } },
        employerInformation: { employerName: 'Acme Corp' }
      }

      # Post without signing in
      post(:create, params: { form214192: form_data })

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #download_pdf' do
    let(:pdf_content) { 'PDF_BINARY_CONTENT' }
    let(:temp_file_path) { '/tmp/test_pdf.pdf' }

    before do
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(temp_file_path)
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(temp_file_path).and_return(pdf_content)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(temp_file_path).and_return(true)
      allow(File).to receive(:delete).and_call_original
      allow(File).to receive(:delete).with(temp_file_path)
    end

    it 'generates and downloads PDF' do
      post(:download_pdf, params: { form: form_data.to_json })

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/pdf')
      expect(response.body).to eq(pdf_content)
    end

    it 'includes proper filename with UUID' do
      post(:download_pdf, params: { form: form_data.to_json })

      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include('21-4192_')
      expect(response.headers['Content-Disposition']).to match(/21-4192_[a-f0-9-]+\.pdf/)
    end

    it 'generates unique filename for each request' do
      post(:download_pdf, params: { form: form_data.to_json })
      first_filename = response.headers['Content-Disposition']

      post(:download_pdf, params: { form: form_data.to_json })
      second_filename = response.headers['Content-Disposition']

      expect(first_filename).not_to eq(second_filename)
    end

    it 'calls PDF filler with correct parameters' do
      expect(PdfFill::Filler).to receive(:fill_ancillary_form)
        .with(hash_including('employmentInformation' => hash_including('employerName' => 'Acme Corporation')),
              anything,
              '21-4192')
        .and_return(temp_file_path)

      post(:download_pdf, params: { form: form_data.to_json })
    end

    it 'deletes temporary PDF file after sending' do
      expect(File).to receive(:delete).with(temp_file_path)
      post(:download_pdf, params: { form: form_data.to_json })
    end

    it 'deletes temporary file even when PDF generation fails' do
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF generation error')
      # File.delete should not be called since source_file_path is nil
      expect(File).not_to receive(:delete)

      post(:download_pdf, params: { form: form_data.to_json })
      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
      expect(json['errors'].first['title']).to eq('PDF Generation Failed')
      expect(json['errors'].first['status']).to eq('500')
    end

    it 'deletes temporary file even when file read fails' do
      allow(File).to receive(:read).with(temp_file_path).and_raise(StandardError, 'Read error')
      expect(File).to receive(:delete).with(temp_file_path)

      post(:download_pdf, params: { form: form_data.to_json })
      expect(response).to have_http_status(:internal_server_error)

      json = JSON.parse(response.body)
      expect(json['errors']).to be_present
      expect(json['errors'].first['title']).to eq('PDF Generation Failed')
    end

    it 'does not require authentication' do
      post(:download_pdf, params: { form: form_data.to_json })

      expect(response).to have_http_status(:ok)
    end

    context 'error handling' do
      it 'returns 400 for invalid JSON' do
        post(:download_pdf, params: { form: 'invalid json {not valid}' })

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['title']).to eq('Invalid JSON')
        expect(json['errors'].first['detail']).to eq('The form data provided is not valid JSON')
        expect(json['errors'].first['status']).to eq('400')
      end

      it 'returns 500 for PDF generation failures' do
        allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF error')

        post(:download_pdf, params: { form: form_data.to_json })

        expect(response).to have_http_status(:internal_server_error)

        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
        expect(json['errors'].first['title']).to eq('PDF Generation Failed')
        expect(json['errors'].first['status']).to eq('500')
      end
    end
  end
end
