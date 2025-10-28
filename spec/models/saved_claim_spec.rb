# frozen_string_literal: true

require 'rails_helper'

class TestSavedClaim < SavedClaim
  FORM = 'some_form_id'
  CONFIRMATION = 'test'

  def regional_office
    'test_office'
  end

  def attachment_keys
    %i[some_key]
  end
end

class TestOpenApiClaim < SavedClaim
  FORM = 'test_form'
  SCHEMA_SOURCE = :openapi3
  OPENAPI_OPERATION_ID = 'submitTestForm'
  CONFIRMATION = 'test'

  def regional_office
    []
  end

  def attachment_keys
    []
  end
end

RSpec.describe TestSavedClaim, type: :model do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:saved_claim) { described_class.new(form: form_data) }

  let(:form_data) { { some_key: 'some_value' }.to_json }
  let(:schema) { { some_key: 'some_value' }.to_json }

  before do
    allow(Flipper).to receive(:enabled?).with(:validate_saved_claims_with_json_schemer).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(true)
    allow(VetsJsonSchema::SCHEMAS).to receive(:[]).and_return(schema)
    allow(JSON::Validator).to receive_messages(fully_validate_schema: [], fully_validate: [])
  end

  describe 'associations' do
    it { is_expected.to have_many(:persistent_attachments).dependent(:destroy) }
    it { is_expected.to have_many(:form_submissions).dependent(:nullify) }
    it { is_expected.to have_many(:claim_va_notifications).dependent(:destroy) }
  end

  describe 'validations' do
    context 'no validation errors' do
      it 'returns true' do
        expect(saved_claim.validate).to be(true)
      end
    end

    context 'validation errors' do
      let(:allowed_errors) do
        {
          data_pointer: 'data_pointer',
          error: 'some error',
          details: { detail: 'thing' },
          schema: { detail: 'schema' },
          root_schema: { detail: 'root_schema' }
        }
      end

      let(:filtered_out_errors) { { data: { key: 'this could be pii' } } }

      let(:schema_errors) { [allowed_errors.merge(filtered_out_errors)] }

      let(:formatted_errors) { { message: 'some error', fragment: 'data_pointer' } }
      let(:filtered_schema_errors) { [allowed_errors.merge(formatted_errors)] }

      context 'when validate_schema returns errors' do
        before do
          allow(JSONSchemer).to receive_messages(validate_schema: schema_errors)
        end

        it 'logs schema failed error' do
          expect(Rails.logger).to receive(:error)
            .with('SavedClaim schema failed validation.', { errors: filtered_schema_errors,
                                                            form_id: saved_claim.form_id })

          expect(saved_claim.validate).to be(true)
        end
      end

      context 'when form validation returns errors' do
        before do
          allow(JSONSchemer).to receive_messages(validate_schema: [])
          allow(JSONSchemer).to receive(:schema).and_return(double(:fake_schema,
                                                                   validate: schema_errors))
        end

        it 'adds validation errors to the form' do
          expect(Rails.logger).to receive(:error)
            .with('SavedClaim form did not pass validation',
                  { guid: saved_claim.guid, form_id: saved_claim.form_id, errors: filtered_schema_errors })
          saved_claim.validate
          expect(saved_claim.errors.full_messages).not_to be_empty
        end
      end
    end
  end

  describe 'callbacks' do
    let(:tags) { ["form_id:#{saved_claim.form_id}", "doctype:#{saved_claim.doctype}"] }

    context 'after create' do
      it 'increments the saved_claim.create metric' do
        allow(StatsD).to receive(:increment)
        saved_claim.save!
        expect(StatsD).to have_received(:increment).with('saved_claim.create', tags:)
      end

      context 'if form_start_date is set' do
        let(:form_start_date) { DateTime.now - 1 }

        it 'increments the saved_claim.time-to-file metric' do
          allow(StatsD).to receive(:measure)
          saved_claim.form_start_date = form_start_date
          saved_claim.save!

          claim_duration = saved_claim.created_at - form_start_date
          expect(StatsD).to have_received(:measure).with(
            'saved_claim.time-to-file',
            be_within(1.second).of(claim_duration),
            tags:
          )
        end
      end

      context 'if form_id is not registered with PdfFill::Filler' do
        it 'skips tracking pdf overflow' do
          allow(StatsD).to receive(:increment)
          saved_claim.save!

          expect(StatsD).to have_received(:increment).with('saved_claim.create',
                                                           tags: ['form_id:SOME_FORM_ID', 'doctype:10'])
          expect(StatsD).not_to have_received(:increment).with('saved_claim.pdf.overflow', tags:)
        end
      end
    end

    context 'after destroy' do
      it 'increments the saved_claim.destroy metric' do
        saved_claim.save!
        allow(StatsD).to receive(:increment)
        saved_claim.destroy
        expect(StatsD).to have_received(:increment).with('saved_claim.destroy', tags:)
      end
    end
  end

  describe 'openapi validations' do
    let(:mock_openapi_doc) do
      {
        'paths' => {
          '/test_form' => {
            'post' => {
              'operationId' => 'submitTestForm',
              'requestBody' => {
                'content' => {
                  'application/json' => {
                    'schema' => {
                      'type' => 'object',
                      'required' => %w[firstName lastName],
                      'properties' => {
                        'firstName' => { 'type' => 'string', 'minLength' => 1 },
                        'lastName' => { 'type' => 'string', 'minLength' => 1 },
                        'age' => { 'type' => 'integer', 'minimum' => 0 }
                      },
                      'additionalProperties' => false
                    }
                  }
                }
              }
            }
          }
        }
      }
    end

    let(:valid_form_data) do
      {
        firstName: 'John',
        lastName: 'Doe',
        age: 30
      }
    end

    let(:invalid_form_data_missing_required) do
      {
        firstName: 'John'
        # Missing lastName (required field)
      }
    end

    let(:invalid_form_data_wrong_type) do
      {
        firstName: 'John',
        lastName: 'Doe',
        age: 'thirty' # Should be integer
      }
    end

    let(:valid_claim) { TestOpenApiClaim.new(form: valid_form_data.to_json) }
    let(:invalid_claim_missing_required) { TestOpenApiClaim.new(form: invalid_form_data_missing_required.to_json) }
    let(:invalid_claim_wrong_type) { TestOpenApiClaim.new(form: invalid_form_data_wrong_type.to_json) }

    before do
      # Clear Rails cache to ensure tests get fresh mocks
      Rails.cache.clear

      # Mock the OpenAPI document file read
      allow(Rails).to receive(:public_path).and_return(
        double(join: double(read: mock_openapi_doc.to_json))
      )
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_openapi_validation).and_return(true)
      end

      it 'validates successfully with valid data' do
        expect(valid_claim).to be_valid
        expect(valid_claim.errors).to be_empty
      end

      it 'adds validation errors when required fields are missing' do
        expect(invalid_claim_missing_required).not_to be_valid
        expect(invalid_claim_missing_required.errors).not_to be_empty
        expect(invalid_claim_missing_required.errors.full_messages).to include(match(/lastName/i))
      end

      it 'adds validation errors when data types are incorrect' do
        expect(invalid_claim_wrong_type).not_to be_valid
        expect(invalid_claim_wrong_type.errors).not_to be_empty
      end

      it 'uses OpenAPI 3.0 meta schema for validation' do
        expect(valid_claim.send(:schema_source)).to eq(:openapi3)
        expect(valid_claim.send(:selected_meta_schema)).to eq(JSONSchemer.openapi30)
      end

      it 'logs errors when validation fails' do
        expect(Rails.logger).to receive(:error).with(
          'SavedClaim form did not pass validation',
          hash_including(:form_id, :guid, :errors)
        )
        invalid_claim_missing_required.valid?
      end
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_openapi_validation).and_return(false)
      end

      it 'falls back to vets-json-schema validation' do
        expect(valid_claim.send(:schema_source)).to eq(:vets_json_schema)
        expect(valid_claim.send(:selected_meta_schema)).to eq(JSONSchemer.draft202012)
      end

      it 'uses vets-json-schema even when SCHEMA_SOURCE is openapi3' do
        # Should fall back to vets-json-schema when FF is disabled
        expect(valid_claim.send(:resolved_validation_schema)).to eq(schema)
      end

      it 'does not use OpenAPI validation path' do
        # Should not attempt to read openapi.json when FF is disabled
        expect(valid_claim).not_to receive(:openapi_request_body_schema)
        valid_claim.valid?
      end
    end

    context 'schema resolution' do
      it 'resolves to OpenAPI schema when opted in and FF enabled' do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_openapi_validation).and_return(true)
        resolved = valid_claim.send(:resolved_validation_schema)
        expect(resolved['type']).to eq('object')
        expect(resolved['required']).to eq(%w[firstName lastName])
      end

      it 'resolves to vets-json-schema when opted in but FF disabled' do
        allow(Flipper).to receive(:enabled?).with(:saved_claim_openapi_validation).and_return(false)
        resolved = valid_claim.send(:resolved_validation_schema)
        expect(resolved).to eq(schema) # Falls back to mocked vets-json-schema
      end

      it 'resolves to vets-json-schema when not opted into OpenAPI' do
        # Use the original TestSavedClaim which doesn't have SCHEMA_SOURCE set
        claim = described_class.new(form: form_data)
        expect(claim.send(:schema_source)).to eq(:vets_json_schema)
      end
    end
  end

  describe '#process_attachments!' do
    let(:confirmation_code) { SecureRandom.uuid }
    let(:form_data) { { some_key: [{ confirmationCode: confirmation_code }] }.to_json }

    it 'processes attachments associated with the claim' do
      attachment = create(:persistent_attachment, guid: confirmation_code, saved_claim:)
      saved_claim.process_attachments!

      expect(attachment.reload.saved_claim_id).to eq(saved_claim.id)
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to have_enqueued_sidekiq_job(saved_claim.id)
    end
  end

  describe '#confirmation_number' do
    it 'returns the claim GUID' do
      expect(saved_claim.confirmation_number).to eq(saved_claim.guid)
    end
  end

  describe '#submitted_at' do
    it 'returns the created_at' do
      expect(saved_claim.submitted_at).to eq(saved_claim.created_at)
    end
  end

  describe '#to_pdf' do
    it 'calls PdfFill::Filler.fill_form' do
      expect(PdfFill::Filler).to receive(:fill_form).with(saved_claim, nil)
      saved_claim.to_pdf
    end
  end

  describe '#update_form' do
    it 'updates the form with new data' do
      saved_claim.update_form('new_key', 'new_value')
      expect(saved_claim.parsed_form['new_key']).to eq('new_value')
    end
  end

  describe '#business_line' do
    it 'returns empty string' do
      expect(saved_claim.business_line).to eq('')
    end
  end

  describe '#insert_notification' do
    it 'creates a new ClaimVANotification record' do
      saved_claim.save!

      expect do
        saved_claim.insert_notification(1)
      end.to change(saved_claim.claim_va_notifications, :count).by(1)
    end
  end

  describe '#va_notification?' do
    let(:email_template_id) { 0 }

    let!(:notification) do
      ClaimVANotification.create(
        saved_claim:,
        email_template_id:,
        form_type: saved_claim.form_id,
        email_sent: false
      )
    end

    it 'returns the notification if it exists' do
      expect(saved_claim.va_notification?(email_template_id)).to eq(notification)
    end

    it 'returns nil if the notification does not exist' do
      expect(saved_claim.va_notification?('non_existent_template')).to be_nil
    end
  end
end
