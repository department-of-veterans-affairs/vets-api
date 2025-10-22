# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form212680Controller, type: :controller do
  describe 'POST #download_pdf' do
    it 'returns PDF generation stub message' do
      form_data = {
        veteranInformation: {
          fullName: { first: 'John', last: 'Doe' },
          ssn: '123456789',
          dateOfBirth: '1990-01-01'
        },
        claimantInformation: {
          fullName: { first: 'Jane', last: 'Doe' },
          relationship: 'Spouse',
          address: {
            street: '123 Main St',
            city: 'Anytown',
            state: 'CA',
            zipCode: '12345'
          }
        },
        benefitInformation: {
          claimType: 'Aid and Attendance'
        },
        veteranSignature: {
          signature: 'John A Doe',
          date: '2025-10-01'
        }
      }

      post(:download_pdf, params: { form212680: form_data })

      expect(response).to have_http_status(:ok)

      json = JSON.parse(response.body)
      expect(json['message']).to include('PDF generation stub')
      expect(json['instructions']).to be_present
      expect(json['instructions']['title']).to include('Next Steps')
      expect(json['instructions']['steps']).to be_an(Array)
      expect(json['instructions']['upload_url']).to be_present
      expect(json['instructions']['form_number']).to eq('21-2680')
      expect(json['instructions']['regional_office']).to include('Pension Management Center')
    end

    it 'does not require authentication' do
      form_data = {
        veteranInformation: {
          fullName: { first: 'John', last: 'Doe' },
          ssn: '123456789'
        }
      }

      post(:download_pdf, params: { form212680: form_data })

      expect(response).to have_http_status(:ok)
    end

    it 'returns consistent instructions structure' do
      form_data = {
        veteranInformation: {
          fullName: { first: 'John', last: 'Doe' },
          ssn: '123456789'
        }
      }

      post(:download_pdf, params: { form212680: form_data })

      json = JSON.parse(response.body)
      instructions = json['instructions']

      expect(instructions['steps']).to include('Download the pre-filled PDF below')
      expect(instructions['steps']).to include('Take the form to your physician')
      expect(instructions['steps']).to include('Have your physician complete Sections VI-VIII')
      expect(instructions['steps']).to include('Upload the completed form at: va.gov/upload-supporting-documents')
    end
  end
end
