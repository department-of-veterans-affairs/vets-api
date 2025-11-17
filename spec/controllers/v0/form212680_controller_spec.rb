# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form212680Controller, type: :controller do
  let(:valid_form_data) do
    { form: VetsJsonSchema::EXAMPLES['21-2680'] }.with_indifferent_access
  end

  describe 'POST #download_pdf' do
    before do
      allow(Flipper).to receive(:enabled?).with(:form_2680_enabled).and_return(true)
    end

    context 'with valid form data' do
      it 'returns a PDF file' do
        post(:download_pdf, params: valid_form_data, as: :json)

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/pdf')
      end

      it 'sets the correct filename' do
        post(:download_pdf, params: valid_form_data, as: :json)

        expect(response.headers['Content-Disposition']).to include('VA_Form_21-2680')
        expect(response.headers['Content-Disposition']).to include('.pdf')
      end

      it 'does not require authentication' do
        post(:download_pdf, params: valid_form_data, as: :json)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with missing form data' do
      it 'returns a parameter missing error' do
        post(:download_pdf, params: {}, as: :json)
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with incomplete veteran sections' do
      let(:incomplete_form_data) do
        # Missing required fields
        { form: {
          veteranInformation: {
            fullName: { first: 'John' }

          }
        } }
      end

      it 'returns 422 unprocessable entity' do
        post(:download_pdf, params: incomplete_form_data, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form_2680_enabled, nil).and_return(false)
      end

      it 'returns 404 Not Found (routing error)' do
        post(:download_pdf, params: valid_form_data, as: :json)
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with invalid SSN' do
      let(:invalid_form_data) do
        valid_form_data['form']['veteranInformation']['ssn'] = '12345'
        valid_form_data
      end

      it 'returns 422 unprocessable entity' do
        post(:download_pdf, params: invalid_form_data, as: :json)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when PDF generation fails' do
      before do
        allow_any_instance_of(SavedClaim::Form212680).to receive(:to_pdf)
          .and_raise(StandardError, 'PDF generation error')
      end

      it 'returns 500 internal server error' do
        post(:download_pdf, params: valid_form_data, as: :json)

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
