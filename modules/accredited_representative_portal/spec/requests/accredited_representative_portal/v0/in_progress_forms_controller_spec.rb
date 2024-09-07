# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/authentication'

RSpec.describe AccreditedRepresentativePortal::V0::InProgressFormsController, type: :request do
  let(:representative_user) { create(:representative_user) }
  let(:expected_response_body) do
    {
      'data' => {
        'id' => in_progress_form.id.to_s,
        'type' => 'in_progress_forms',
        'attributes' => {
          'formId' => in_progress_form.form_id,
          'createdAt' => in_progress_form.created_at,
          'updatedAt' => in_progress_form.updated_at,
          'metadata' => in_progress_form.metadata
        }
      }
    }
  end

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(representative_user)
  end

  describe 'PUT /update' do
    let(:form_data) { { field: 'value' } }

    context 'with an existing InProgressForm' do
      let!(:in_progress_form) { create(:in_progress_form, user_uuid: representative_user.uuid) }

      it 'updates the InProgressForm' do
        headers = { 'Content-Type' => 'application/json' }
        put("/accredited_representative_portal/v0/in_progress_forms/#{in_progress_form.form_id}", params: { form_data: form_data }.to_json, headers:)

        expect(response).to have_http_status(:ok)
        in_progress_form.reload
        expect(response.body).to eq(expected_response_body.to_json)
      end
    end

    context 'without an existing InProgressForm' do
      let(:form_id) { '21a' }
      let(:in_progress_form) { InProgressForm.last }

      it 'create InProgressForm' do
        headers = { 'Content-Type' => 'application/json' }
        put("/accredited_representative_portal/v0/in_progress_forms/#{form_id}", params: { form_data: form_data }.to_json, headers:)

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(expected_response_body.to_json)
      end
    end
  end

  describe 'GET /show' do
    let!(:in_progress_form) { create(:in_progress_form, user_uuid: representative_user.uuid) }

    context 'with an existing InProgressForm' do
      it 'returns the InProgressForm and form data' do
        get("/accredited_representative_portal/v0/in_progress_forms/#{in_progress_form.form_id}")

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(
          'formData' => JSON.parse(in_progress_form.form_data),
          'metadata' => in_progress_form.metadata
        )
      end
    end
  end

  describe 'DELETE /destroy' do
    context 'with an existing InProgressForm' do
      let!(:in_progress_form) { create(:in_progress_form, user_uuid: representative_user.uuid) }

      it 'deletes the InProgressForm' do
        delete("/accredited_representative_portal/v0/in_progress_forms/#{in_progress_form.form_id}")

        expect(response).to have_http_status(:ok)
        expect(response.body).to eq(expected_response_body.to_json)
        expect(InProgressForm.exists?(in_progress_form.id)).to be false

        get("/accredited_representative_portal/v0/in_progress_forms/#{in_progress_form.form_id}")
        expect(response.body).to eq({}.to_json)
      end
    end

    context 'with a nonexistant InProgressForm' do
      let(:form_id) { 'sample_form_id' }

      it 'returns a RecordNotFound error' do
        delete("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
