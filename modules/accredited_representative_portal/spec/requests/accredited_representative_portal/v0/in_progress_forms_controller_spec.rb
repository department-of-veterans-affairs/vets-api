# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../support/authentication'

RSpec.describe AccreditedRepresentativePortal::V0::InProgressFormsController, type: :request do
  let(:representative_user) { create(:representative_user) }
  let(:initial_request_date) { Time.utc(2022, 3, 4, 5, 6, 7) }
  let(:form_id) { '21a' }
  let(:headers) { { 'Content-Type' => 'application/json' } }
  let(:in_progress_form_id) { InProgressForm.last.id }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(representative_user)
  end

  describe 'requests' do
    context 'can make requests to InProgressForms controller' do
      it 'can make requests to InProgressForms controller' do
        # Test for GET and DELETE of existing InProgressForm
        Timecop.freeze(initial_request_date) do
          form_data = { field: 'value' }
          initial_in_progress_form = create(
            :in_progress_form,
            user_uuid: representative_user.uuid,
            form_data:,
            form_id:
          )
          get("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
          expect(JSON.parse(response.body)).to eq(
            {
              'formData' => {
                'field' => 'value'
              },
              'metadata' => {
                'version' => 1,
                'return_url' => 'foo.com',
                'createdAt' => 1_646_370_367,
                'expiresAt' => 1_651_554_367,
                'lastUpdated' => 1_646_370_367,
                'inProgressFormId' => initial_in_progress_form.id
              }
            }
          )

          delete("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
          expect(response).to have_http_status(:no_content)
        end

        # Test for PUT when InProgressForm does not exist
        Timecop.freeze(initial_request_date + 1.day) do
          form_data = { another_field: 'foo' }
          put(
            "/accredited_representative_portal/v0/in_progress_forms/#{form_id}",
            params: { 'formData' => form_data }.to_json,
            headers:
          )
          expect(JSON.parse(response.body)).to eq(
            {
              'data' => {
                'id' => in_progress_form_id.to_s,
                'type' => 'in_progress_forms',
                'attributes' => {
                  'formId' => '21a',
                  'createdAt' => '2022-03-05T05:06:07.000Z',
                  'updatedAt' => '2022-03-05T05:06:07.000Z',
                  'metadata' => {
                    'createdAt' => 1_646_456_767,
                    'expiresAt' => 1_651_640_767,
                    'lastUpdated' => 1_646_456_767,
                    'inProgressFormId' => in_progress_form_id
                  }
                }
              }
            }
          )

          get("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
          expect(JSON.parse(response.body)).to eq(
            {
              'formData' => {
                'another_field' => 'foo'
              },
              'metadata' => {
                'createdAt' => 1_646_456_767,
                'expiresAt' => 1_651_640_767,
                'lastUpdated' => 1_646_456_767,
                'inProgressFormId' => in_progress_form_id
              }
            }
          )
        end

        # Test for PUT and DELETE when InProgressForm does exist
        Timecop.freeze(initial_request_date + 2.days) do
          form_data = { another_field: 'foo', sample_field: 'sample' }
          put(
            "/accredited_representative_portal/v0/in_progress_forms/#{form_id}",
            params: { 'formData' => form_data }.to_json,
            headers:
          )
          expect(JSON.parse(response.body)).to eq(
            {
              'data' => {
                'id' => in_progress_form_id.to_s,
                'type' => 'in_progress_forms',
                'attributes' => {
                  'formId' => '21a',
                  'createdAt' => '2022-03-05T05:06:07.000Z',
                  'updatedAt' => '2022-03-06T05:06:07.000Z',
                  'metadata' => {
                    'createdAt' => 1_646_456_767,
                    'expiresAt' => 1_651_727_167,
                    'lastUpdated' => 1_646_543_167,
                    'inProgressFormId' => in_progress_form_id
                  }
                }
              }
            }
          )

          get("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
          expect(JSON.parse(response.body)).to eq(
            {
              'formData' => {
                'another_field' => 'foo',
                'sample_field' => 'sample'
              },
              'metadata' => {
                'createdAt' => 1_646_456_767,
                'expiresAt' => 1_651_727_167,
                'lastUpdated' => 1_646_543_167,
                'inProgressFormId' => in_progress_form_id
              }
            }
          )

          delete("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
          expect(response).to have_http_status(:no_content)

          get("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
          expect(response.body).to eq({}.to_json)
        end
      end
    end
  end
end
