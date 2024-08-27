# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'NextStepsEmailController', type: :request do
  describe 'POST #create' do
    let(:base_path) { '/representation_management/v0/next_steps_email' }
    let(:params) do
      {
        next_steps_email: {
          email_address: 'email@example.com',
          first_name: 'First',
          form_name: 'Form Name',
          form_number: 'Form Number',
          representative_type: 'Type',
          representative_name: 'Name',
          representative_address: 'Address'
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

      it 'responds with the expected body' do
        expect(response.body).to eq({ message: 'Email enqueued' }.to_json)
      end
    end

    context 'when triggering validation errors' do
      context 'when submitting without the organization name for a single validation error' do
        before do
          params[:next_steps_email][:email_address] = nil
          post(base_path, params:)
        end

        it 'responds with an unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to eq({ errors: ["Email address can't be blank"] }.to_json)
        end
      end

      context 'when submitting without multiple required attributes' do
        before do
          params[:next_steps_email][:email_address] = nil
          params[:next_steps_email][:first_name] = nil
          params[:next_steps_email][:representative_type] = nil
          params[:next_steps_email][:representative_name] = nil
          post(base_path, params:)
        end

        it 'responds with an unprocessable entity status' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'responds with the expected body' do
          expect(response.body).to include("Email address can't be blank")
          expect(response.body).to include("First name can't be blank")
          expect(response.body).to include("Representative type can't be blank")
          expect(response.body).to include("Representative name can't be blank")
        end
      end
    end
  end
end
