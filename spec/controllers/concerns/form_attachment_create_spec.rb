# frozen_string_literal: true

shared_examples_for 'a FormAttachmentCreate controller' do |user_factory: nil|
  describe '::FORM_ATTACHMENT_MODEL' do
    it 'is a FormAttachment model' do
      expect(described_class::FORM_ATTACHMENT_MODEL.ancestors).to include(FormAttachment)
    end
  end

  describe '#create' do
    let(:form_attachment_guid) { SecureRandom.uuid }
    let(:form_attachment_model) { described_class::FORM_ATTACHMENT_MODEL }
    let(:resource_name) { form_attachment_model.to_s.underscore.split('/').last }
    let(:json_api_type) { form_attachment_model.name.remove('::').snakecase.pluralize }

    before do
      if user_factory
        sign_in_as(
          build(:user, user_factory)
        )
      end
    end

    it 'requires params.`resource_name`' do
      empty_req_params = [nil, {}]
      empty_req_params << { resource_name => {} }
      empty_req_params.each do |params|
        post(:create, params: params)

        expect(response).to have_http_status(:bad_request)

        response_body = JSON.parse(response.body)

        expect(response_body['errors'].size).to eq(1)
        expect(response_body['errors'][0]).to eq(
          'title' => 'Missing parameter',
          'detail' => "The required parameter \"#{resource_name}\", is missing",
          'code' => '108',
          'status' => '400'
        )
      end
    end

    def expect_form_attachment_creation(req_params:) # rubocop:disable Metrics/AbcSize
      form_attachment = build(resource_name.to_sym, guid: form_attachment_guid)

      expect(form_attachment_model).to receive(:new) do
        expect(form_attachment).to receive(:set_file_data!).with(
          req_params[resource_name][:file_data],
          req_params[resource_name][:password]
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
      params[resource_name] = { file_data: 'uploaded_document' }

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
