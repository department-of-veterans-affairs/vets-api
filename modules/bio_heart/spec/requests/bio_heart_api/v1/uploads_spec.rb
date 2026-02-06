# frozen_string_literal: true

require 'rails_helper'
require 'bio_heart_api/form_mapper_registry'
require 'ibm/service'

RSpec.describe 'BioHeartApi::V1::Uploads', type: :request do
  let(:user) { build(:user, :loa3) }
  let(:form_number) { '21P-0537' }
  let(:form_data) { { some: 'data', veteran_info: { name: 'John Doe' } } }
  let(:params) do
    {
      form_number:,
      form_data:
    }
  end
  let(:confirmation_number) { 'c44f39ea-29e4-4504-9e7e-12689a51d00a' }
  let(:benefits_intake_response) do
    {
      confirmation_number:,
      submission_api: 'benefitsIntake'
    }.to_json
  end
  let(:ibm_service) { instance_double(Ibm::Service) }
  let(:mapper) { BioHeartApi::FormMappers::Form21p0537Mapper }
  let(:transformed_payload) { { ibm_field: 'transformed_value' } }

  before do
    sign_in(user)
    allow(Flipper).to receive(:enabled?).with(:form21p0537, user).and_return(true)
    allow(Flipper).to receive(:enabled?).with(:bio_heart_mms_logging).and_return(true)
    allow(BioHeartApi::FormMapperRegistry).to receive(:mapper_for).with(form_number).and_return(mapper)
    allow(mapper).to receive(:transform).and_return(transformed_payload)
    allow(Ibm::Service).to receive(:new).and_return(ibm_service)
  end

  describe 'POST /bio_heart_api/v1/bio_heart' do
    context 'when parent submit succeeds with confirmation number' do
      before do
        # Mock the benefits intake service inside parent controller's submit method
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController)
          .to receive(:submit_form_to_benefits_intake)
          .and_return(json: JSON.parse(benefits_intake_response), status: :ok)
      end

      context 'when Flipper is enabled for MMS' do
        before do
          allow(Flipper).to receive(:enabled?).with(:bio_heart_mms_submit).and_return(true)
        end

        it 'submits to both Benefits Intake and IBM MMS' do
          expect(ibm_service).to receive(:upload_form).with(
            form: transformed_payload.to_json,
            guid: confirmation_number
          )

          post('/bio_heart_api/v1/bio_heart', params:)

          expect(response.body).to eq(benefits_intake_response)
        end

        it 'logs successful MMS submission' do
          allow(ibm_service).to receive(:upload_form).and_return(status: 200, body: '', headers: {})

          expect(Rails.logger).to receive(:info).with("BioHeart MMS submission complete: #{confirmation_number}")

          post('/bio_heart_api/v1/bio_heart', params:)
        end

        it 'transforms params using the correct mapper' do
          allow(ibm_service).to receive(:upload_form)

          expect(BioHeartApi::FormMapperRegistry).to receive(:mapper_for).with(form_number)
          expect(mapper).to receive(:transform).with(hash_including('form_number' => form_number))

          post('/bio_heart_api/v1/bio_heart', params:)
        end

        context 'when IBM service fails' do
          let(:error_message) { 'Connection timeout' }

          before do
            allow(ibm_service).to receive(:upload_form).and_raise(StandardError.new(error_message))
          end

          it 'logs the error and still returns success from Benefits Intake' do
            expect(Rails.logger).to receive(:error).with(
              "BioHeart MMS submission failed: #{error_message}",
              form_number:,
              guid: confirmation_number
            )

            post('/bio_heart_api/v1/bio_heart', params:)

            expect(response.body).to eq(benefits_intake_response)
          end

          it 'does not re-raise the exception' do
            allow(Rails.logger).to receive(:error)

            expect { post('/bio_heart_api/v1/bio_heart', params:) }.not_to raise_error
          end
        end
      end

      context 'when Flipper is disabled for MMS' do
        before do
          allow(Flipper).to receive(:enabled?).with(:bio_heart_mms_submit).and_return(false)
        end

        it 'does not submit to IBM MMS' do
          expect(ibm_service).not_to receive(:upload_form)

          post('/bio_heart_api/v1/bio_heart', params:)

          expect(response).to have_http_status(:ok)
        end

        it 'still returns the Benefits Intake response' do
          post('/bio_heart_api/v1/bio_heart', params:)

          expect(response.body).to eq(benefits_intake_response)
        end
      end
    end

    context 'when parent submit returns response without confirmation number' do
      before do
        allow(Flipper).to receive(:enabled?).with(:bio_heart_mms_submit).and_return(true)
      end

      context 'with nil response' do
        before do
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:submit).and_return(nil)
        end

        it 'does not attempt IBM submission' do
          expect(ibm_service).not_to receive(:upload_form)

          post('/bio_heart_api/v1/bio_heart', params:)
        end
      end

      context 'with empty string response' do
        before do
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:submit).and_return('')
        end

        it 'does not attempt IBM submission' do
          expect(ibm_service).not_to receive(:upload_form)

          post('/bio_heart_api/v1/bio_heart', params:)
        end
      end

      context 'with invalid JSON response' do
        before do
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:submit)
            .and_return('not valid json')
        end

        it 'does not attempt IBM submission' do
          expect(ibm_service).not_to receive(:upload_form)

          post '/bio_heart_api/v1/bio_heart', params:
        end
      end

      context 'with JSON response missing confirmation_number' do
        before do
          allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:submit)
            .and_return({ submission_api: 'benefitsIntake' }.to_json)
        end

        it 'does not attempt IBM submission' do
          expect(ibm_service).not_to receive(:upload_form)

          post '/bio_heart_api/v1/bio_heart', params:
        end
      end
    end

    context 'when parent submit raises an exception' do
      before do
        allow(Flipper).to receive(:enabled?).with(:bio_heart_mms_submit).and_return(true)
        allow_any_instance_of(SimpleFormsApi::V1::UploadsController).to receive(:submit)
          .and_raise(StandardError.new('Benefits Intake API error'))
      end

      it 'does not attempt IBM submission' do
        expect(ibm_service).not_to receive(:upload_form)
        post '/bio_heart_api/v1/bio_heart', params:
      end
    end
  end

  describe '#extract_confirmation_number' do
    let(:controller) { BioHeartApi::V1::UploadsController.new }

    it 'returns false for nil' do
      expect(controller.send(:extract_confirmation_number, nil)).to be false
    end

    it 'returns false for empty string' do
      expect(controller.send(:extract_confirmation_number, '')).to be false
    end

    it 'returns false for blank string' do
      expect(controller.send(:extract_confirmation_number, '   ')).to be false
    end

    it 'extracts confirmation_number from JSON string' do
      json_string = { confirmation_number: 'test-123', submission_api: 'benefitsIntake' }.to_json
      expect(controller.send(:extract_confirmation_number, json_string)).to eq('test-123')
    end

    it 'extracts confirmation_number from hash' do
      hash = { 'confirmation_number' => 'test-456', 'submission_api' => 'benefitsIntake' }
      expect(controller.send(:extract_confirmation_number, hash)).to eq('test-456')
    end

    it 'returns false for JSON string without confirmation_number' do
      json_string = { submission_api: 'benefitsIntake' }.to_json
      expect(controller.send(:extract_confirmation_number, json_string)).to be false
    end

    it 'returns false for hash without confirmation_number' do
      hash = { 'submission_api' => 'benefitsIntake' }
      expect(controller.send(:extract_confirmation_number, hash)).to be false
    end

    it 'returns false for invalid JSON string' do
      expect(controller.send(:extract_confirmation_number, 'not valid json')).to be false
    end

    it 'returns false for JSON with null confirmation_number' do
      json_string = { confirmation_number: nil, submission_api: 'benefitsIntake' }.to_json
      expect(controller.send(:extract_confirmation_number, json_string)).to be false
    end

    it 'returns false for JSON with empty confirmation_number' do
      json_string = { confirmation_number: '', submission_api: 'benefitsIntake' }.to_json
      expect(controller.send(:extract_confirmation_number, json_string)).to be false
    end
  end
end
