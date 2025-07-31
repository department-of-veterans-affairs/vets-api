# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe AccreditedRepresentativePortal::V0::InProgressFormsController, type: :request do
  let(:representative_user) { create(:representative_user) }
  let(:form_id) { '21a' }
  let(:headers) { { 'Content-Type' => 'application/json' } }

  before do
    Flipper.enable(:accredited_representative_portal_pilot)
    login_as(representative_user)
  end

  after { Flipper.disable(:accredited_representative_portal_pilot) }

  describe 'requests' do
    context 'can make requests to InProgressForms controller' do
      it 'can make requests to InProgressForms controller' do
        # Test for GET and DELETE of existing InProgressForm
        travel_to Time.utc(2022, 3, 4, 5, 6, 7)

        create(
          :in_progress_form,
          user_uuid: representative_user.uuid,
          form_data: { field: 'value' },
          form_id:,
          metadata: {
            version: 1,
            returnUrl: 'foo.com'
          }
        )

        get("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
        expect(parsed_response).to eq(
          {
            'formData' => {
              'field' => 'value'
            },
            'metadata' => {
              'version' => 1,
              'returnUrl' => 'foo.com',
              'createdAt' => 1_646_370_367,
              'expiresAt' => 1_651_554_367,
              'lastUpdated' => 1_646_370_367,
              'inProgressFormId' => InProgressForm.last.id
            }
          }
        )

        delete("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
        expect(response).to have_http_status(:no_content)

        # Test for PUT when InProgressForm does not exist
        travel 1.day

        put(
          "/accredited_representative_portal/v0/in_progress_forms/#{form_id}",
          params: { 'formData' => { anotherField: 'foo' } }.to_json,
          headers:
        )

        expect(parsed_response).to eq(
          {
            'data' => {
              'id' => '',
              'type' => 'in_progress_forms',
              'attributes' => {
                'formId' => '21a',
                'createdAt' => '2022-03-05T05:06:07.000Z',
                'updatedAt' => '2022-03-05T05:06:07.000Z',
                'metadata' => {
                  'createdAt' => 1_646_456_767,
                  'expiresAt' => 1_651_640_767,
                  'lastUpdated' => 1_646_456_767,
                  'inProgressFormId' => InProgressForm.last.id
                }
              }
            }
          }
        )

        get("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
        expect(parsed_response).to eq(
          {
            'formData' => {
              'anotherField' => 'foo'
            },
            'metadata' => {
              'createdAt' => 1_646_456_767,
              'expiresAt' => 1_651_640_767,
              'lastUpdated' => 1_646_456_767,
              'inProgressFormId' => InProgressForm.last.id
            }
          }
        )

        # Test for PUT and DELETE when InProgressForm does exist
        travel 1.day

        put(
          "/accredited_representative_portal/v0/in_progress_forms/#{form_id}",
          params: { 'formData' => { anotherField: 'foo', sampleField: 'sample' } }.to_json,
          headers:
        )

        expect(parsed_response).to eq(
          {
            'data' => {
              'id' => '',
              'type' => 'in_progress_forms',
              'attributes' => {
                'formId' => '21a',
                'createdAt' => '2022-03-05T05:06:07.000Z',
                'updatedAt' => '2022-03-06T05:06:07.000Z',
                'metadata' => {
                  'createdAt' => 1_646_456_767,
                  'expiresAt' => 1_651_727_167,
                  'lastUpdated' => 1_646_543_167,
                  'inProgressFormId' => InProgressForm.last.id
                }
              }
            }
          }
        )

        get("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
        expect(parsed_response).to eq(
          {
            'formData' => {
              'anotherField' => 'foo',
              'sampleField' => 'sample'
            },
            'metadata' => {
              'createdAt' => 1_646_456_767,
              'expiresAt' => 1_651_727_167,
              'lastUpdated' => 1_646_543_167,
              'inProgressFormId' => InProgressForm.last.id
            }
          }
        )

        delete("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
        expect(response).to have_http_status(:no_content)

        get("/accredited_representative_portal/v0/in_progress_forms/#{form_id}")
        expect(response.body).to eq({}.to_json)

        travel_back
      end
    end
  end
end
