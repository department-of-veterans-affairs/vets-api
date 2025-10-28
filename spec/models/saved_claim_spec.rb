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

RSpec.describe TestSavedClaim, type: :model do
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

  describe '#process_attachments!' do
    let(:confirmation_code) { SecureRandom.uuid }
    let(:form_data) { { some_key: [{ confirmationCode: confirmation_code }] }.to_json }

    it 'processes attachments associated with the claim' do
      attachment = create(:persistent_attachment, guid: confirmation_code, saved_claim:)
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(saved_claim.id)
      saved_claim.process_attachments!

      expect(attachment.reload.saved_claim_id).to eq(saved_claim.id)
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

# ---- OpenAPI validation specs ----

class SavedClaim::OpenApiTest < SavedClaim
  FORM = '21-4192'
  SCHEMA_SOURCE = :openapi3
  OPENAPI_OPERATION_ID = 'submitForm214192'
end

class SavedClaim::OpenApiNoOpId < SavedClaim
  FORM = '21-4192'
  SCHEMA_SOURCE = :openapi3
end

RSpec.describe SavedClaim::OpenApiTest, type: :model do
  let(:valid_payload) do
    {
      veteranInformation: {
        fullName: { first: 'John', last: 'Doe' },
        dateOfBirth: '1980-01-01'
      },
      employmentInformation: {
        employerName: 'ACME',
        employerAddress: {
          street: '123 Main', city: 'Town', state: 'CA', postalCode: '90210', country: 'USA'
        },
        typeOfWorkPerformed: 'Work',
        beginningDateOfEmployment: '2020-01-01'
      }
    }
  end

  let(:openapi_doc) do
    {
      'openapi' => '3.0.3',
      'paths' => {
        '/v0/form214192' => {
          'post' => {
            'operationId' => 'submitForm214192',
            'requestBody' => {
              'content' => {
                'application/json' => {
                  'schema' => {
                    'type' => 'object',
                    'properties' => {
                      'veteranInformation' => {
                        'type' => 'object',
                        'required' => %w[fullName dateOfBirth],
                        'properties' => {
                          'fullName' => {
                            'type' => 'object',
                            'required' => %w[first last],
                            'properties' => {
                              'first' => { 'type' => 'string' },
                              'last' => { 'type' => 'string' }
                            }
                          },
                          'dateOfBirth' => { 'type' => 'string' }
                        }
                      },
                      'employmentInformation' => {
                        'type' => 'object',
                        'required' => %w[employerName employerAddress typeOfWorkPerformed beginningDateOfEmployment],
                        'properties' => {
                          'employerName' => { 'type' => 'string' },
                          'employerAddress' => {
                            'type' => 'object',
                            'required' => %w[street city state postalCode country],
                            'properties' => {
                              'street' => { 'type' => 'string' },
                              'city' => { 'type' => 'string' },
                              'state' => { 'type' => 'string' },
                              'postalCode' => { 'type' => 'string' },
                              'country' => { 'type' => 'string' }
                            }
                          },
                          'typeOfWorkPerformed' => { 'type' => 'string' },
                          'beginningDateOfEmployment' => { 'type' => 'string' }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  end

  before do
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with(Rails.public_path.join('openapi.json')).and_return(openapi_doc.to_json)
  end

  context 'when feature flag is enabled' do
    before do
      Flipper.enable(:saved_claim_openapi_validation)
    end

    after do
      Flipper.disable(:saved_claim_openapi_validation)
    end

    it 'validates against the OpenAPI requestBody schema' do
      claim = described_class.new(form: valid_payload.to_json)
      expect(claim).to be_valid
    end

    it 'adds errors for invalid payload' do
      invalid = valid_payload.dup
      invalid[:veteranInformation].delete(:dateOfBirth)
      claim = described_class.new(form: invalid.to_json)
      expect(claim).not_to be_valid
      expect(claim.errors).not_to be_empty
    end
  end

  context 'when feature flag is disabled' do
    before do
      Flipper.disable(:saved_claim_openapi_validation)
      stub_const('VetsJsonSchema::SCHEMAS', { '21-4192' => { 'type' => 'object' } })
    end

    it 'falls back to VetsJsonSchema' do
      claim = described_class.new(form: valid_payload.to_json)
      expect(claim).to be_valid
    end
  end
end

RSpec.describe SavedClaim::OpenApiNoOpId, type: :model do
  let(:payload) { { foo: 'bar' } }

  before do
    allow(File).to receive(:read).and_call_original
  end

  context 'when feature flag is enabled' do
    before { Flipper.enable(:saved_claim_openapi_validation) }
    after { Flipper.disable(:saved_claim_openapi_validation) }

    it 'raises a KeyError requiring OPENAPI_OPERATION_ID' do
      claim = described_class.new(form: payload.to_json)
      expect { claim.valid? }.to raise_error(KeyError, /OPENAPI_OPERATION_ID must be defined/)
    end
  end

  context 'when feature flag is disabled' do
    before do
      Flipper.disable(:saved_claim_openapi_validation)
      stub_const('VetsJsonSchema::SCHEMAS', { '21-4192' => { 'type' => 'object' } })
    end

    it 'falls back to VetsJsonSchema and does not require OPENAPI_OPERATION_ID' do
      claim = described_class.new(form: payload.to_json)
      expect { claim.valid? }.not_to raise_error
      expect(claim).to be_valid
    end
  end
end
