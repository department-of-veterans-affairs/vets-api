# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'RepresentationManagement::V0::PdfGenerator2122a', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/pdf_generator2122a' }
    let(:representative) do
      create(:accredited_individual,
             first_name: 'John',
             middle_initial: 'M',
             last_name: 'Representative',
             address_line1: '123 Fake Representative St',
             city: 'Portland',
             state_code: 'OR',
             zip_code: '12345',
             phone: '5555555555',
             email: 'representative@example.com',
             individual_type: 'attorney')
    end
    let(:params) do
      {
        pdf_generator2122a: {
          representative_submission_method: 'digital',
          record_consent: true,
          consent_address_change: true,
          consent_limits: [],
          consent_inside_access: true,
          consent_outside_access: true,
          consent_team_members: [
            'Jane M Representative',
            'John M Representative',
            'Jane M Doe',
            'John M Doe',
            'Bobbie M Law',
            'Bob M Law',
            'Alice M Aster',
            'Arthur M Aster'
          ],
          claimant: {
            date_of_birth: '1980-12-31',
            relationship: 'Spouse',
            phone: '5555555555',
            email: 'claimant@example.com',
            name: {
              first: 'John',
              middle: 'M',
              last: 'Claimant'
            },
            address: {
              address_line1: '123 Fake Claimant St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'US',
              zip_code: '12345',
              zip_code_suffix: '6789'
            }
          },
          veteran: {
            ssn: '123456789',
            va_file_number: '123456789',
            date_of_birth: '1980-12-31',
            service_number: 'AA12345',
            phone: '5555555555',
            email: 'veteran@example.com',
            name: {
              first: 'John',
              middle: 'M',
              last: 'Veteran'
            },
            address: {
              address_line1: '123 Fake Veteran St',
              address_line2: '',
              city: 'Portland',
              state_code: 'OR',
              country: 'US',
              zip_code: '12345',
              zip_code_suffix: '6789'
            }
          },
          representative: {
            id: representative.id
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
        params[:pdf_generator2122a][:representative_submission_method] = 'paper'

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

    context 'When submitting a legacy representative' do
      before do
        legacy_representative = create(:representative, zip_code: '12345')
        params[:pdf_generator2122a][:representative][:id] = legacy_representative.representative_id
        post(base_path, params:)
      end

      it 'responds with an ok status' do
        expect(response).to have_http_status(:ok)
      end

      it 'responds with a PDF' do
        expect(response.content_type).to eq('application/pdf')
      end
    end

    context 'When submitting without consent_team_members' do
      before do
        params[:pdf_generator2122a].delete(:consent_team_members)
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
      context 'when submitting without the representative first name for a single validation error' do
        before do
          params[:pdf_generator2122a][:veteran][:name][:first] = nil
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
