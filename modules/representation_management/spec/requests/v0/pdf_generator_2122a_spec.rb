# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PdfGenerator2122aController', type: :request do
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

    context 'when submitting valid data' do
      context 'When submitting all fields' do
        it 'responds with a created status' do
          post(base_path, params:)
          expect(response).to have_http_status(:created)
        end

        it 'responds with a PDF' do
          post(base_path, params:)
          expect(response.content_type).to eq('application/pdf')
        end
      end
    end

    context 'when submitting valid data without optional fields' do
      context 'When submitting all fields except claimant' do
        before do
          params[:pdf_generator2122a].delete(:claimant)
        end

        it 'responds with a created status' do
          post(base_path, params:)
          expect(response).to have_http_status(:created)
        end

        it 'responds with a PDF' do
          post(base_path, params:)
          expect(response.content_type).to eq('application/pdf')
        end
      end

      context 'When submitting none of the optional fields' do
        before do
          params[:pdf_generator2122a][:veteran][:name].delete(:middle)
          params[:pdf_generator2122a][:veteran].delete(:va_file_number)
          params[:pdf_generator2122a][:veteran][:address].delete(:address_line2)
          params[:pdf_generator2122a][:veteran][:address].delete(:zip_code_suffix)
          params[:pdf_generator2122a][:veteran].delete(:phone)
          params[:pdf_generator2122a][:veteran].delete(:service_number)
          params[:pdf_generator2122a].delete(:claimant)
          params[:pdf_generator2122a][:representative][:name].delete(:middle)
          params[:pdf_generator2122a][:representative][:address].delete(:address_line2)
          params[:pdf_generator2122a][:representative][:address].delete(:zip_code_suffix)
        end

        it 'responds with a created status' do
          post(base_path, params:)
          expect(response).to have_http_status(:created)
        end

        it 'responds with a PDF' do
          post(base_path, params:)
          expect(response.content_type).to eq('application/pdf')
        end
      end
    end

    context 'when submitting incomplete data' do
      context 'when submitting without the representative type' do
        it 'responds with an unprocessable entity status' do
          params[:pdf_generator2122a][:representative][:type] = nil
          post(base_path, params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          params[:pdf_generator2122a][:representative][:type] = nil
          post(base_path, params:)
          expect(response.body).to include("Representative type can't be blank")
          expect(response.body).to include('Representative type is not included in the list')
        end
      end

      context 'when submitting without the veteran first name' do
        it 'responds with an unprocessable entity status' do
          params[:pdf_generator2122a][:veteran][:name][:first] = nil
          post(base_path, params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          params[:pdf_generator2122a][:veteran][:name][:first] = nil
          post(base_path, params:)
          expect(response.body).to eq({ errors: ["Veteran first name can't be blank"] }.to_json)
        end
      end

      context 'When submitting without the veteran social security number' do
        it 'responds with an unprocessable entity status' do
          params[:pdf_generator2122a][:veteran][:ssn] = nil
          post(base_path, params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          params[:pdf_generator2122a][:veteran][:ssn] = nil
          post(base_path, params:)
          expect(response.body).to include("Veteran social security number can't be blank")
          expect(response.body).to include('Veteran social security number is invalid')
        end
      end

      context 'When submitting without multiple required fields' do
        it 'responds with an unprocessable entity status' do
          params[:pdf_generator2122a][:veteran][:name][:last] = nil
          params[:pdf_generator2122a][:veteran][:date_of_birth] = nil
          post(base_path, params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          params[:pdf_generator2122a][:veteran][:name][:last] = nil
          params[:pdf_generator2122a][:veteran][:date_of_birth] = nil
          post(base_path, params:)
          expect(response.body).to include("Veteran last name can't be blank")
          expect(response.body).to include("Veteran date of birth can't be blank")
        end
      end
    end

    context 'when submitting invalid data' do
      context "When submitting a veteran's state code that is too long" do
        it 'responds with an unprocessable entity status' do
          params[:pdf_generator2122a][:veteran][:address][:state_code] = 'TOO_LONG'
          post(base_path, params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          params[:pdf_generator2122a][:veteran][:address][:state_code] = 'TOO_LONG'
          post(base_path, params:)
          expect(response.body).to eq({ errors: ['Veteran state code is the wrong length (should be 2 characters)'] }.to_json)
        end
      end

      context 'When submitting a veteran zip code that is too short' do
        it 'responds with an unprocessable entity status' do
          params[:pdf_generator2122a][:veteran][:address][:zip_code] = '1234'
          post(base_path, params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          params[:pdf_generator2122a][:veteran][:address][:zip_code] = '1234'
          post(base_path, params:)
          expect(response.body).to include('Veteran zip code is the wrong length (should be 5 characters)')
          expect(response.body).to include('Veteran zip code is invalid')
        end
      end

      context 'When submitting a veteran va file number with non numeric characters' do
        it 'responds with an unprocessable entity status' do
          params[:pdf_generator2122a][:veteran][:va_file_number] = '12345678A'
          post(base_path, params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          params[:pdf_generator2122a][:veteran][:va_file_number] = '12345678A'
          post(base_path, params:)
          expect(response.body).to eq({ errors: ['Veteran VA file number is invalid'] }.to_json)
        end
      end

      context 'When submitting an invalid representative type' do
        it 'responds with an unprocessable entity status' do
          params[:pdf_generator2122a][:representative][:type] = 'INVALID_TYPE'
          post(base_path, params:)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          params[:pdf_generator2122a][:representative][:type] = 'INVALID_TYPE'
          post(base_path, params:)
          expect(response.body).to eq({ errors: ['Representative type is not included in the list'] }.to_json)
        end
      end
    end
  end
end
