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

RSpec.describe TestSavedClaim, type: :model do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:saved_claim) { described_class.new(form: form_data) }

  let(:form_data) { { some_key: 'some_value' }.to_json }
  let(:schema) { { some_key: 'some_value' }.to_json }

  before do
    allow(Flipper).to receive(:enabled?).with(:validate_saved_claims_with_json_schemer).and_return(false)
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
      context 'using JSON Schema' do
        before do
          allow(JSON::Validator).to receive(:fully_validate).and_return([])
        end

        it 'returns true' do
          expect(saved_claim.validate).to eq true
        end
      end

      context 'using JSON Schemer' do
        before do
          allow(Flipper).to receive(:enabled?).with(:validate_saved_claims_with_json_schemer).and_return(true)
        end

        it 'returns true' do
          expect(saved_claim.validate).to eq(true)
        end
      end
    end

    context 'validation errors' do
      let(:schema_errors) { [{ fragment: 'error' }] }

      context 'using JSON Schema' do
        context 'when fully_validate_schema returns errors' do
          before do
            allow(Flipper).to receive(:enabled?).with(:saved_claim_schema_validation_disable).and_return(false)
            allow(JSON::Validator).to receive_messages(fully_validate_schema: schema_errors, fully_validate: [])
          end

          it 'logs schema failed error and calls fully_validate' do
            expect(Rails.logger).to receive(:error)
              .with('SavedClaim schema failed validation! Attempting to clear cache.', { errors: schema_errors })

            expect(saved_claim.validate).to eq true
          end
        end

        context 'when fully_validate returns errors' do
          before do
            allow(JSON::Validator).to receive(:fully_validate).and_return(schema_errors)
          end

          it 'adds validation errors to the form' do
            saved_claim.validate
            expect(saved_claim.errors.full_messages).not_to be_empty
          end
        end

        context 'when JSON:Validator.fully_validate_schema throws an exception' do
          let(:exception) { StandardError.new('Some exception') }

          before do
            allow(Flipper).to receive(:enabled?).with(:saved_claim_schema_validation_disable).and_return(true)
            allow(JSON::Validator).to receive(:fully_validate_schema).and_raise(exception)
            allow(JSON::Validator).to receive(:fully_validate).and_return([])
          end

          it 'logs exception and raises exception' do
            expect(Rails.logger).to receive(:error)
              .with('Error during schema validation!', { error: exception.message, backtrace: anything, schema: })

            expect { saved_claim.validate }.to raise_error(exception.class, exception.message)
          end
        end

        context 'when JSON:Validator.fully_validate throws an exception' do
          let(:exception) { StandardError.new('Some exception') }

          before do
            allow(JSON::Validator).to receive(:fully_validate_schema).and_return([])
            allow(JSON::Validator).to receive(:fully_validate).and_raise(exception)
          end

          it 'logs exception and raises exception' do
            expect(Rails.logger).to receive(:error)
              .with('Error during form validation!', { error: exception.message, backtrace: anything, schema:,
                                                       clear_cache: false })

            expect(PersonalInformationLog).to receive(:create).with(
              data: { schema: schema,
                      parsed_form: saved_claim.parsed_form,
                      params: { errors_as_objects: true, clear_cache: false } },
              error_class: 'SavedClaim FormValidationError'
            )

            expect { saved_claim.validate }.to raise_error(exception.class, exception.message)
          end
        end
      end

      context 'using JSON Schemer' do
        before do
          allow(Flipper).to receive(:enabled?).with(:validate_saved_claims_with_json_schemer).and_return(true)
        end

        context 'when validate_schema returns errors' do
          before do
            allow(Flipper).to receive(:enabled?).with(:saved_claim_schema_validation_disable).and_return(false)
            allow(JSONSchemer).to receive_messages(validate_schema: schema_errors)
          end

          it 'logs schema faild error' do
            expect(Rails.logger).to receive(:error)
              .with('SavedClaim schema failed validation! Attempting to clear cache.', { errors: schema_errors })

            expect(saved_claim.validate).to eq(true)
          end
        end

        context 'when form validation returns errors' do
          before do
            allow(JSONSchemer).to receive_messages(validate_schema: [])
            allow(JSONSchemer).to receive(:schema).and_return(double(:fake_schema, validate: [{ data_pointer: "error" }]))
          end

          it 'adds validation errors to the form' do
            saved_claim.validate
            expect(saved_claim.errors.full_messages).not_to be_empty
            byebug
          end
        end
      end
    end
  end

  describe 'callbacks' do
    context 'after create' do
      it 'increments the saved_claim.create metric' do
        allow(StatsD).to receive(:increment)
        saved_claim.save!
        expect(StatsD).to have_received(:increment).with('saved_claim.create', tags: ["form_id:#{saved_claim.form_id}"])
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
            tags: ["form_id:#{saved_claim.form_id}"]
          )
        end
      end
    end

    context 'after destroy' do
      it 'increments the saved_claim.destroy metric' do
        saved_claim.save!
        allow(StatsD).to receive(:increment)
        saved_claim.destroy
        expect(StatsD).to have_received(:increment).with('saved_claim.destroy',
                                                         tags: ["form_id:#{saved_claim.form_id}"])
      end
    end
  end

  describe '#process_attachments!' do
    let(:confirmation_code) { SecureRandom.uuid }
    let(:form_data) { { some_key: [{ confirmationCode: confirmation_code }] }.to_json }

    it 'processes attachments associated with the claim' do
      attachment = create(:persistent_attachment, guid: confirmation_code, saved_claim: saved_claim)
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
        saved_claim: saved_claim,
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
