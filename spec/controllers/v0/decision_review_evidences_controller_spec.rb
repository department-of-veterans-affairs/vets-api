# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::DecisionReviewEvidencesController, type: :controller do
  describe '::FORM_ATTACHMENT_MODEL' do
    it 'is a FormAttachment model' do
      expect(described_class::FORM_ATTACHMENT_MODEL.ancestors).to include(FormAttachment)
    end
  end

  describe '#create' do
    let(:form_attachment_guid) { SecureRandom.uuid }
    let(:pdf_file) do
      fixture_file_upload('doctors-note.pdf', 'application/pdf')
    end
    let(:form_attachment_model) { described_class::FORM_ATTACHMENT_MODEL }
    let(:param_namespace) { form_attachment_model.to_s.underscore.split('/').last }
    let(:resource_name) { form_attachment_model.name.remove('::').snakecase }
    let(:json_api_type) { resource_name.pluralize }
    let(:attachment_factory_id) { resource_name.to_sym }

    before do
      sign_in_as(
        build(:user, :loa1)
      )
    end

    it 'requires params.`param_namespace`' do
      empty_req_params = [nil, {}]
      empty_req_params << { param_namespace => {} }
      empty_req_params.each do |params|
        post(:create, params:)

        expect(response).to have_http_status(:bad_request)

        response_body = JSON.parse(response.body)

        expect(response_body['errors'].size).to eq(1)
        expect(response_body['errors'][0]).to eq(
          'title' => 'Missing parameter',
          'detail' => "The required parameter \"#{param_namespace}\", is missing",
          'code' => '108',
          'status' => '400'
        )
      end
    end

    it 'requires file_data to be a file' do
      params = { param_namespace => { file_data: 'not_a_file_just_a_string' } }
      post(:create, params:)
      expect(response).to have_http_status(:bad_request)
      response_body_errors = JSON.parse(response.body)['errors']

      expect(response_body_errors.size).to eq(1)
      expect(response_body_errors[0]).to eq(
        'title' => 'Invalid field value',
        'detail' => '"String" is not a valid value for "file_data"',
        'code' => '103',
        'status' => '400'
      )
    end

    def expect_form_attachment_creation
      form_attachment = build(attachment_factory_id, guid: form_attachment_guid)

      expect(form_attachment_model).to receive(:new) do
        expect(form_attachment).to receive(:set_file_data!)

        expect(form_attachment).to receive(:save!) do
          form_attachment.id = 99
          form_attachment
        end

        form_attachment
      end

      expect(subject).to receive(:render).with(json: form_attachment).and_call_original # rubocop:disable RSpec/SubjectStub

      form_attachment
    end

    it 'creates a FormAttachment' do
      params = { param_namespace => { file_data: pdf_file } }
      expect_form_attachment_creation
      post(:create, params:)

      expect(response).to have_http_status(:ok)
      expect(
        JSON.parse(response.body)
      ).to eq(
        {
          'data' => {
            'id' => '99',
            'type' => json_api_type,
            'attributes' => {
              'guid' => form_attachment_guid
            }
          }
        }
      )
    end
  end
end
