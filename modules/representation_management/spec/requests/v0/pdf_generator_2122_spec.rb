# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'PdfGenerator2122Controller', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/pdf_generator2122' }

    context 'when submitting all required data' do
      let(:all_required_params) do
        {
          pdf_generator2122: {
            organization_name: 'My Organization',
            record_consent: '',
            consent_address_change: '',
            consent_limits: [],
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
            }
          }
        }
      end

      it 'responds with a created status' do
        post base_path, params: all_required_params
        p "response: #{response.inspect}"
        expect(response).to have_http_status(:created)
      end
    end

    context 'when submitting incomplete data' do
      let(:params) do
        {
          pdf_generator2122: {
            record_consent: '',
            consent_address_change: '',
            consent_limits: [],
            claimant: {
              date_of_birth: '1980-01-01',
              relationship: 'Spouse',
              phone: '5555555555',
              email: 'claimant@example.com',
              name: {
                first: 'ClaimantFirst',
                middle: 'ClaimantMiddle',
                last: 'ClaimantLast'
              },
              address: {
                address_line1: '123 Claimant St',
                address_line2: 'Apt 1',
                city: 'ClaimantCity',
                state_code: 'CC',
                country: 'ClaimantCountry',
                zip_code: '12345',
                zip_code_suffix: '6789'
              }
            },
            veteran: {
              ssn: '123456789',
              va_file_number: '987654321',
              date_of_birth: '1970-01-01',
              service_number: 'SRV123456',
              phone: '5555555555',
              email: 'veteran@example.com',
              insurance_numbers: [],
              name: {
                first: 'VeteranFirst',
                middle: 'VeteranMiddle',
                last: 'VeteranLast'
              },
              address: {
                address_line1: '456 Veteran Rd',
                address_line2: 'Suite 2',
                city: 'VeteranCity',
                state_code: 'VC',
                country: 'US',
                zip_code: '98765',
                zip_code_suffix: '4321'
              }
            }
          }
        }
      end

      it 'responds with an unprocessable entity status' do
        post(base_path, params:)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
