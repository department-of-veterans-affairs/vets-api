# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DigitalFormsApi::SubmissionsController, type: :controller do
  routes { DigitalFormsApi::Engine.routes }

  let(:user) { create(:user) }

  before do
    sign_in_as(user) if user.present?
  end

  describe '#show' do
    def retrieve_submission!
      VCR.use_cassette("digital_forms/#{cassette}") do
        get(:show, params: { id: 'abc123' })
      end
    end

    context 'when the submission is found' do
      let(:cassette) { 'retrieve_686c' }

      it 'returns the submission and template' do
        VCR.use_cassette("digital_forms/template_686c") do
          retrieve_submission!
        end
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to include('submission', 'template')
      end
    end

    context 'when the submission is not found' do
      let(:cassette) { 'retrieve_686c_404' }

      it 'returns a 404 error' do
        retrieve_submission!
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when any unexpected error occurs' do
      let(:cassette) { 'retrieve_686c_403' }

      it 'returns a 500 error' do
        retrieve_submission!
        expect(response).to have_http_status(:internal_server_error)
      end
    end

    context 'when user is not logged in' do
      let(:user) { nil }

      it 'returns a 401 error without hitting Forms API' do
        get(:show, params: { id: 'abc123' })
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
