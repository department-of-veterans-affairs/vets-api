# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form212680Controller, type: :controller do
  let(:valid_form_data) do
    {
      veteranInformation: {
        fullName: { first: 'John', middle: 'A', last: 'Doe' },
        ssn: '123456789',
        vaFileNumber: '987654321',
        dateOfBirth: '1950-01-01'
      },
      claimantInformation: {
        fullName: { first: 'Jane', middle: 'B', last: 'Doe' },
        relationship: 'Spouse',
        address: {
          street: '123 Main St',
          city: 'Springfield',
          state: 'IL',
          postalCode: '62701'
        }
      },
      benefitInformation: {
        claimType: 'Aid and Attendance'
      },
      additionalInformation: {
        currentlyHospitalized: false,
        nursingHome: false
      },
      veteranSignature: {
        signature: 'John A Doe',
        date: Time.zone.today.to_s
      }
    }
  end

  describe 'POST #download_pdf' do
    context 'with valid form data' do
      it 'returns a PDF file' do
        post(:download_pdf, params: { form212680: valid_form_data })

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/pdf')
      end

      it 'sets the correct filename' do
        post(:download_pdf, params: { form212680: valid_form_data })

        expect(response.headers['Content-Disposition']).to include('VA_Form_21-2680')
        expect(response.headers['Content-Disposition']).to include('.pdf')
      end

      it 'does not require authentication' do
        post(:download_pdf, params: { form212680: valid_form_data })

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with missing form data' do
      it 'returns a parameter missing error' do
        post(:download_pdf, params: {})

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with incomplete veteran sections' do
      let(:incomplete_form_data) do
        {
          veteranInformation: {
            fullName: { first: 'John' }
            # Missing required fields
          }
        }
      end

      it 'returns 422 unprocessable entity' do
        post(:download_pdf, params: { form212680: incomplete_form_data })

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid SSN' do
      let(:invalid_form_data) do
        data = valid_form_data.deep_dup
        data[:veteranInformation][:ssn] = '12345'
        data
      end

      it 'returns 422 unprocessable entity' do
        post(:download_pdf, params: { form212680: invalid_form_data })

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with signature older than 60 days' do
      let(:old_signature_form_data) do
        data = valid_form_data.deep_dup
        data[:veteranSignature][:date] = 61.days.ago.to_date.to_s
        data
      end

      it 'returns 422 unprocessable entity' do
        post(:download_pdf, params: { form212680: old_signature_form_data })

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when PDF generation fails' do
      before do
        allow_any_instance_of(SavedClaim::Form212680).to receive(:to_pdf)
          .and_raise(StandardError, 'PDF generation error')
      end

      it 'returns 500 internal server error' do
        post(:download_pdf, params: { form212680: valid_form_data })

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end

  describe 'POST #submit' do
    it 'returns stub message' do
      post(:submit, params: { form212680: valid_form_data })

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['message']).to include('Form submission stub')
      expect(json['message']).to include('not yet implemented')
      expect(json['message']).to include('va.gov/upload-supporting-documents')
    end

    it 'does not require form data' do
      post(:submit, params: {})

      expect(response).to have_http_status(:ok)
    end
  end
end
