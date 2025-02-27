# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::PdfGenerator2122', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/pdf_generator2122' }
    let(:organization) { create(:organization) } # This is the legacy organization
    let(:representative) { create(:representative) } # This is the legacy representative
    let(:params) do
      {
        pdf_generator2122: {
          representative_submission_method: 'digital',
          record_consent: '',
          consent_address_change: '',
          consent_limits: [],
          claimant: {
            date_of_birth: '1980-12-31',
            relationship: 'Spouse',
            phone: '555-555-5555', # This is a 10 digit phone number as submitted by the frontend
            email: 'claimant@example.com',
            name: {
              first: 'John',
              middle: 'Middle', # This is a middle name as submitted by the frontend
              last: 'Claimant'
            },
            address: {
              address_line1: '123 Fake Claimant St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'USA', # This is a 3 character country code as submitted by the frontend
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
            phone: '555-555-5555', # This is a 10 digit phone number as submitted by the frontend
            email: 'veteran@example.com',
            name: {
              first: 'John',
              middle: 'Middle', # This is a middle name as submitted by the frontend
              last: 'Veteran'
            },
            address: {
              address_line1: '123 Fake Veteran St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'USA', # This is a 3 character country code as submitted by the frontend
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

    context "When representative_submission_method is 'digital'" do
      it 'does not clear the saved form' do
        expect_any_instance_of(ApplicationController).not_to receive(:clear_saved_form).with('21-22')

        post(base_path, params:)
      end
    end

    context "When representative_submission_method is not 'digital'" do
      it 'clears the saved form' do
        params[:pdf_generator2122][:representative_submission_method] = 'paper'

        expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('21-22').once

        post(base_path, params:)
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

    context 'When submitting a valid request with the accredited organization and individual ids' do
      before do
        accredited_organization = create(:accredited_organization)
        accredited_individual = create(:accredited_individual)
        params[:pdf_generator2122][:representative][:organization_id] = accredited_organization.id
        params[:pdf_generator2122][:representative][:id] = accredited_individual.id
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
