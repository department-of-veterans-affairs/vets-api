# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::PdfGenerator2122a', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/pdf_generator2122a' }
    let(:params) do
      {
        pdf_generator2122a: {
          record_consent: '',
          consent_address_change: '',
          consent_limits: [],
          conditions_of_appointment: [],
          claimant: {
            date_of_birth: '1980-01-01',
            relationship: 'Spouse',
            phone: '5555555555',
            email: 'claimant@example.com',
            name: {
              first: 'First',
              middle: 'M',
              last: 'Last'
            },
            address: {
              address_line1: '123 Claimant St',
              address_line2: '',
              city: 'ClaimantCity',
              state_code: 'CC',
              country: 'US',
              zip_code: '12345',
              zip_code_suffix: '6789'
            }
          },
          veteran: {
            ssn: '123456789',
            va_file_number: '987654321',
            date_of_birth: '1970-01-01',
            service_number: '123123456',
            phone: '5555555555',
            email: 'veteran@example.com',
            insurance_numbers: [],
            name: {
              first: 'First',
              middle: 'M',
              last: 'Last'
            },
            address: {
              address_line1: '456 Veteran Rd',
              address_line2: '',
              city: 'VeteranCity',
              state_code: 'VC',
              country: 'US',
              zip_code: '98765',
              zip_code_suffix: '4321'
            }
          },
          representative: {
            type: 'ATTORNEY',
            phone: '5555555555',
            email: 'rep@rep.com',
            name: {
              first: 'First',
              middle: 'M',
              last: 'Last'
            },
            address: {
              address_line1: '789 Rep St',
              address_line2: '',
              city: 'RepCity',
              state_code: 'RC',
              country: 'US',
              zip_code: '54321',
              zip_code_suffix: '9876'
            }
          }
        }
      }
    end

    context 'When submitting all fields with valid data' do
      before do
        post(base_path, params:)
      end

      it 'responds with a ok status' do
        expect(response).to have_http_status(:ok)
      end

      it 'responds with a PDF' do
        expect(response.content_type).to eq('application/pdf')
      end
    end

    context 'when triggering validation errors' do
      context 'when submitting without the representative first name for a single validation error' do
        before do
          params[:pdf_generator2122a][:representative][:name][:first] = nil
          post(base_path, params:)
        end

        it 'responds with an unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to eq({ errors: ["Representative first name can't be blank"] }.to_json)
        end
      end

      context 'when submitting without multiple required attributes' do
        before do
          params[:pdf_generator2122a][:veteran][:name][:first] = nil
          params[:pdf_generator2122a][:veteran][:ssn] = nil
          params[:pdf_generator2122a][:veteran][:name][:last] = nil
          params[:pdf_generator2122a][:veteran][:date_of_birth] = nil
          post(base_path, params:)
        end

        it 'responds with an unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to include("Veteran first name can't be blank")
          expect(response.body).to include("Veteran social security number can't be blank")
          expect(response.body).to include('Veteran social security number is invalid')
          expect(response.body).to include("Veteran last name can't be blank")
          expect(response.body).to include("Veteran date of birth can't be blank")
        end
      end
    end
  end
end
