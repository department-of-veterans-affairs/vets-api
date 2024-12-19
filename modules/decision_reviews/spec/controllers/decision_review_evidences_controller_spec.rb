# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'

RSpec.describe DecisionReviews::V1::DecisionReviewEvidencesController, type: :controller do
  routes { DecisionReviews::Engine.routes }

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
    let(:user) { build(:user, :loa1) }

    before do
      sign_in_as(user)
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

    context 'with a param password' do
      let(:encrypted_log_params_success) do
        {
          message: 'Evidence upload to s3 success!',
          user_uuid: user.uuid,
          action: 'Evidence upload to s3',
          form_id: '10182',
          upstream_system: nil,
          downstream_system: 'AWS S3',
          is_success: true,
          http: {
            status_code: nil,
            body: nil
          },
          form_attachment_guid:,
          encrypted: true
        }
      end

      let(:expected_response_body) do
        {
          'data' => {
            'id' => '99',
            'type' => json_api_type,
            'attributes' => {
              'guid' => form_attachment_guid
            }
          }
        }
      end

      it 'creates a FormAttachment, logs formatted success message, and increments statsd' do
        request.env['SOURCE_APP'] = '10182-board-appeal'
        params = { param_namespace => { file_data: pdf_file, password: 'test_password' } }

        expect(Common::PdfHelpers).to receive(:unlock_pdf)
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(encrypted_log_params_success)
        expect(StatsD).to receive(:increment).with('decision_review.form_10182.evidence_upload_to_s3.success')
        form_attachment = build(attachment_factory_id, guid: form_attachment_guid)

        expect(form_attachment_model).to receive(:new) do
          expect(form_attachment).to receive(:set_file_data!)

          expect(form_attachment).to receive(:save!) do
            form_attachment.id = 99
            form_attachment
          end

          form_attachment
        end

        post(:create, params:)

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(expected_response_body)
      end
    end

    context 'evidence is uploaded from the NOD (10182) form' do
      it 'formatted success log and statsd metric are specific to NOD (10182)' do
        request.env['SOURCE_APP'] = '10182-board-appeal'
        params = { param_namespace => { file_data: pdf_file } }
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(hash_including(form_id: '10182'))
        expect(StatsD).to receive(:increment).with('decision_review.form_10182.evidence_upload_to_s3.success')
        post(:create, params:)
      end
    end

    context 'evidence is uploaded from the SC (995) form' do
      it 'formatted success log and statsd metric are specific to SC (995)' do
        request.env['SOURCE_APP'] = '995-supplemental-claim'
        params = { param_namespace => { file_data: pdf_file } }
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(hash_including(form_id: '995'))
        expect(StatsD).to receive(:increment).with('decision_review.form_995.evidence_upload_to_s3.success')
        post(:create, params:)
      end
    end

    context 'evidence is uploaded from a form with an unexpected Source-App-Name' do
      it 'logs formatted success log and increments success statsd metric, but also increments an `unexpected_form_id` statsd metric' do # rubocop:disable Layout/LineLength
        request.env['SOURCE_APP'] = '997-supplemental-claim'
        params = { param_namespace => { file_data: pdf_file } }
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info).with(hash_including(form_id: '997-supplemental-claim'))
        expect(StatsD).to receive(:increment).with('decision_review.form_997-supplemental-claim.evidence_upload_to_s3.success') # rubocop:disable Layout/LineLength
        expect(StatsD).to receive(:increment).with('decision_review.evidence_upload_to_s3.unexpected_form_id')
        post(:create, params:)
      end
    end

    context 'an error is thrown during file upload' do
      it 'logs formatted error, increments statsd, and raises error' do
        request.env['SOURCE_APP'] = '10182-board-appeal'
        params = { param_namespace => { file_data: pdf_file } }
        expect(StatsD).to receive(:increment).with('decision_review.form_10182.evidence_upload_to_s3.failure')
        allow(Rails.logger).to receive(:error)
        expect(Rails.logger).to receive(:error).with({
                                                       message: 'Evidence upload to s3 failure!',
                                                       user_uuid: user.uuid,
                                                       action: 'Evidence upload to s3',
                                                       form_id: '10182',
                                                       upstream_system: nil,
                                                       downstream_system: 'AWS S3',
                                                       is_success: false,
                                                       http: {
                                                         status_code: 422,
                                                         body: 'Unprocessable Entity'
                                                       },
                                                       form_attachment_guid:,
                                                       encrypted: false
                                                     })
        form_attachment = build(attachment_factory_id, guid: form_attachment_guid)
        expect(form_attachment_model).to receive(:new).and_return(form_attachment)
        expected_error = Common::Exceptions::UnprocessableEntity.new(
          detail: 'Test Error!',
          source: 'FormAttachment.set_file_data'
        )
        expect(form_attachment).to receive(:set_file_data!).and_raise(expected_error)
        post(:create, params:)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(
          {
            'errors' => [{
              'title' => 'Unprocessable Entity',
              'detail' => 'Test Error!',
              'code' => '422',
              'source' => 'FormAttachment.set_file_data',
              'status' => '422'
            }]
          }
        )
      end
    end
  end
end
