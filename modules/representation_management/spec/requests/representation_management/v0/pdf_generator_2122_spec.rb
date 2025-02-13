# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::PdfGenerator2122', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/pdf_generator2122' }
    let(:organization) { create(:organization) }
    let(:representative) { create(:representative) }
    let(:user) { create(:user) }
    let(:params) do
      {
        pdf_generator2122: {
          record_consent: '',
          consent_address_change: '',
          consent_limits: [],
          claimant: {
            date_of_birth: '1980-12-31',
            relationship: 'Spouse',
            phone: '555-555-5555',
            email: 'claimant@example.com',
            name: {
              first: 'John',
              middle: 'Middle',
              last: 'Claimant'
            },
            address: {
              address_line1: '123 Fake Claimant St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'USA',
              zip_code: '12345',
              zip_code_suffix: '6789'
            }
          },
          veteran: {
            ssn: '123456789',
            va_file_number: '123456789',
            date_of_birth: '1980-12-31',
            service_number: '123456789',
            service_branch: 'ARMY',
            phone: '555-555-5555',
            email: 'veteran@example.com',
            name: {
              first: 'John',
              middle: 'Middle',
              last: 'Veteran'
            },
            address: {
              address_line1: '123 Fake Veteran St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'USA',
              zip_code: '12345',
              zip_code_suffix: '6789'
            }
          },
          representative: {
            organization_id: organization.poa,
            id: representative.representative_id
          }
        }
      }
    end

    context 'when user is authenticated' do
      it 'calls clear_saved_form and form_for_user' do
        sign_in(user)

        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)

        allow(InProgressForm).to receive(:form_for_user)

        post(base_path, params:)

        expect(InProgressForm).to have_received(:form_for_user).with('21-22', user)
      end
    end

    context 'when user is not authenticated' do
      it 'calls clear_saved_form but does not call form_for_user' do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)

        allow(InProgressForm).to receive(:form_for_user)

        post(base_path, params:)

        expect(InProgressForm).not_to have_received(:form_for_user)
      end
    end

    context 'When submitting all fields with valid data' do
      before { post(base_path, params:) }

      it 'responds with an ok status' do
        expect(response).to have_http_status(:ok)
      end

      it 'responds with a PDF' do
        expect(response.content_type).to eq('application/pdf')
      end
    end

    context 'When submitting a valid request without a claimant' do
      before do
        params[:pdf_generator2122].delete(:claimant)
        post(base_path, params:)
      end

      it 'responds with an ok status' do
        expect(response).to have_http_status(:ok)
      end

      it 'responds with a PDF' do
        expect(response.content_type).to eq('application/pdf')
      end
    end

    context 'When submitting a valid request without a representative id' do
      before do
        params[:pdf_generator2122][:representative].delete(:id)
        post(base_path, params:)
      end

      it 'responds with an ok status' do
        expect(response).to have_http_status(:ok)
      end

      it 'responds with a PDF' do
        expect(response.content_type).to eq('application/pdf')
      end
    end

    context 'when triggering validation errors' do
      context 'when submitting without the veteran first name for a single validation error' do
        before do
          params[:pdf_generator2122][:veteran][:name][:first] = nil
          post(base_path, params:)
        end

        it 'responds with an unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to eq({ errors: ["Veteran first name can't be blank"] }.to_json)
        end
      end

      context 'when submitting without multiple required attributes' do
        before do
          params[:pdf_generator2122][:veteran][:name][:first] = nil
          params[:pdf_generator2122][:veteran][:ssn] = nil
          params[:pdf_generator2122][:veteran][:name][:last] = nil
          params[:pdf_generator2122][:veteran][:date_of_birth] = nil
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
