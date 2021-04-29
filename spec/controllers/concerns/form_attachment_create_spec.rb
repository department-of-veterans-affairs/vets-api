# frozen_string_literal: true

shared_examples_for 'a FormAttachmentCreate controller' do |user_factory: nil, attachment_factory: nil|
  describe '::FORM_ATTACHMENT_MODEL' do
    it 'is a FormAttachment model' do
      expect(described_class::FORM_ATTACHMENT_MODEL.ancestors).to include(FormAttachment)
    end
  end

  describe '#create' do
    let(:form_attachment_guid) { SecureRandom.uuid }
    let(:form_attachment_model) { described_class::FORM_ATTACHMENT_MODEL }
    let(:param_namespace) { form_attachment_model.to_s.underscore.split('/').last }
    let(:resource_name) { form_attachment_model.name.remove('::').snakecase }
    let(:json_api_type) { resource_name.pluralize }
    let(:attachment_factory_id) { attachment_factory || resource_name.to_sym }

    before do
      if user_factory
        sign_in_as(
          build(:user, user_factory)
        )
      end
    end

    it 'requires params.`param_namespace`' do
      empty_req_params = [nil, {}]
      empty_req_params << { param_namespace => {} }
      empty_req_params.each do |params|
        post(:create, params: params)

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

    def expect_form_attachment_creation(req_params:)
      form_attachment = build(attachment_factory_id, guid: form_attachment_guid)

      expect(form_attachment_model).to receive(:new) do
        expect(form_attachment).to receive(:set_file_data!).with(
          req_params[param_namespace][:file_data],
          req_params[param_namespace][:password]
        )

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
      params = {}
      params[param_namespace] = { file_data: 'uploaded_document' }

      expect_form_attachment_creation(req_params: params)
      post(:create, params: params)

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
