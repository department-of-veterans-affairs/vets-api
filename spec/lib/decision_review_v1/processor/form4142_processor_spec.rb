# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/utilities/form_4142_processor'

describe DecisionReviewV1::Processor::Form4142Processor do
  let(:user) { build(:disabilities_compensation_user) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end
  let(:form_json) do
    # File.read('spec/support/disability_compensation_form/submissions/with_4142.json')
    File.read('spec/support/disability_compensation_form/submissions/with_4142_2024.json')
  end

  let(:saved_claim) { create(:va526ez) }
  let(:submission) do
    create(:form526_submission,
           user_uuid: user.uuid,
           auth_headers_json: auth_headers.to_json,
           saved_claim_id: saved_claim.id,
           form_json:,
           submitted_claim_id: 1)
  end
  let(:processor) do
    described_class.new(form_data: submission.form['form4142'], submission_id: submission.id, validate: true)
  end
  let(:received_date) do
    submission.created_at.in_time_zone(described_class::TIMEZONE).strftime(described_class::SIGNATURE_TIMESTAMP_FORMAT)
  end
  let(:form4142) { JSON.parse(form_json)['form4142'].merge({ 'signatureDate' => received_date }) }

  describe '#initialize' do
    context 'when schema validation is not enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form4142_validate_schema).and_return(false)
      end

      context 'with invalid form data' do
        context 'when a required field is missing' do
          let(:invalid_form_data) { form4142.except('providerFacility') }

          it 'does not raise a validation error' do
            expect { described_class.new(form_data: invalid_form_data, submission_id: submission.id) }
              .not_to raise_error
          end
        end
      end
    end

    context 'when schema validation flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form4142_validate_schema).and_return(true)
        allow(Flipper).to receive(:enabled?).with(:decision_review_form4142_use_2024_template).and_return(false)
      end

      context 'with valid form data' do
        it 'initializes with submission and form data' do
          expect(PdfFill::Filler).to receive(:fill_ancillary_form)
            .and_call_original
            .once
            .with(form4142, anything, described_class::FORM_SCHEMA_ID)
          # Note on the expectation: #anything is a special keyword that matches any argument.
          # We used it here since the uuid is created at runtime.

          expect(processor.instance_variable_get(:@submission)).to eq(submission)
          expect(processor.instance_variable_get(:@pdf_path)).to be_a(String)
          expect(processor.instance_variable_get(:@request_body)).to be_a(Hash)
        end

        context 'when more than 5 providers are submitted' do
          let(:overflow_form_data) do
            form4142.tap do |data|
              # If the number of providers is greater than 5, the overflow page is added
              extra_providers = data['providerFacility'].first.dup
              data['providerFacility'] += [extra_providers] * 5
            end
          end

          it 'does not raise a validation error' do
            expect { described_class.new(form_data: overflow_form_data, submission_id: submission.id) }
              .not_to raise_error
          end
        end
      end

      context 'with invalid form data' do
        context 'when a required field is missing' do
          let(:invalid_form_data) { form4142.except('providerFacility') }

          it 'raises a validation error' do
            expect { described_class.new(form_data: invalid_form_data, submission_id: submission.id) }
              .to raise_error do |error|
                expect(error).to be_a Processors::Form4142ValidationError
                expect(error.message).to include("did not contain a required property of 'providerFacility'")
              end
          end
        end

        context 'with invalid provider data' do
          context 'when dates are malformed' do
            let(:invalid_form_data) do
              form4142.tap do |data|
                data['providerFacility'].first['treatmentDateRange'].first['from'] = 'not-a-date'
              end
            end

            it 'raises a validation error' do
              expect { described_class.new(form_data: invalid_form_data, submission_id: submission.id) }
                .to raise_error do |error|
                expect(error).to be_a Processors::Form4142ValidationError
                expect(error.message).to include('value \"not-a-date\" did not match the regex')
              end
            end
          end
        end

        context 'when required provider fields are missing' do
          %w[providerFacilityName providerFacilityAddress treatmentDateRange].each do |field|
            context "when #{field} is missing" do
              let(:invalid_form_data) do
                form4142.tap do |data|
                  data['providerFacility'].first.delete(field)
                end
              end

              it 'raises a validation error' do
                expect { described_class.new(form_data: invalid_form_data, submission_id: submission.id) }
                  .to raise_error do |error|
                  expect(error).to be_a Processors::Form4142ValidationError
                  expect(error.message).to include("did not contain a required property of '#{field}'")
                end
              end
            end
          end
        end

        context 'when provider state code is invalid' do
          let(:invalid_form_data) do
            form4142.tap do |data|
              data['providerFacility'].first['providerFacilityAddress']['state'] = 'NotAState'
            end
          end

          it 'raises a validation error' do
            expect { described_class.new(form_data: invalid_form_data, submission_id: submission.id) }
              .to raise_error do |error|
                expect(error).to be_a Processors::Form4142ValidationError
                expect(error.message).to include('value \"USA\" did not match one of the following values: CAN')
              end
          end
        end
      end

      context 'setting a correct signed-at date' do
        context 'when a submission was created more than a day before processing' do
          let!(:created_at) { 6.months.ago.in_time_zone(described_class::TIMEZONE) }

          it 'sets the signed at date to the date of submission creation' do
            Timecop.freeze(created_at) { submission }

            key = described_class::SIGNATURE_DATE_KEY
            time_format = described_class::SIGNATURE_TIMESTAMP_FORMAT
            sig_dat = processor.instance_variable_get('@form')[key]
            expect(sig_dat).to eq(created_at.strftime(time_format))
          end
        end
      end
    end

    # New tests for the validation flag
    context 'when validation is explicitly disabled' do
      context 'with invalid form data' do
        let(:invalid_form_data) { form4142.except('providerFacility') }

        it 'does not raise a validation error even when flipper is enabled' do
          allow(Flipper).to receive(:enabled?).with(:form4142_validate_schema).and_return(true)

          expect { described_class.new(form_data: invalid_form_data, submission_id: submission.id, validate: false) }
            .not_to raise_error
        end
      end
    end

    context 'when validation is explicitly enabled' do
      context 'with invalid form data' do
        let(:invalid_form_data) { form4142.except('providerFacility') }

        it 'raises a validation error when flipper is enabled' do
          allow(Flipper).to receive(:enabled?).with(:form4142_validate_schema).and_return(true)

          expect { described_class.new(form_data: invalid_form_data, submission_id: submission.id, validate: true) }
            .to raise_error(Processors::Form4142ValidationError)
        end

        it 'does not raise a validation error when flipper is disabled' do
          allow(Flipper).to receive(:enabled?).with(:form4142_validate_schema).and_return(false)

          expect { described_class.new(form_data: invalid_form_data, submission_id: submission.id, validate: true) }
            .not_to raise_error
        end
      end
    end
  end

  describe 'PDF version selection via feature flag' do
    let(:template_flag) { :decision_review_form4142_use_2024_template }
    let(:validation_flag) { :form4142_validate_schema }

    before do
      # Isolate template testing from validation
      allow(Flipper).to receive(:enabled?).with(validation_flag).and_return(false)
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_call_original
    end

    describe 'template selection logic' do
      context 'with legacy template (flag disabled)' do
        before do
          allow(Flipper).to receive(:enabled?).with(template_flag).and_return(false)
        end

        it 'selects 2018 legacy form class ID' do
          expect(processor.send(:generate_2024_version?)).to be false
          expect(processor.send(:selected_form_class_id)).to eq('21-4142')
        end

        it 'calls PDF filler with 2018 legacy form ID' do
          expect(PdfFill::Filler).to receive(:fill_ancillary_form)
            .with(hash_including('veteranFullName' => anything), anything, '21-4142')

          processor
        end

        it 'does not require signature stamping' do
          expect(processor.send(:needs_signature_stamp?)).to be false
        end
      end

      context 'with 2024 template (flag enabled)' do
        before do
          allow(Flipper).to receive(:enabled?).with(template_flag).and_return(true)
        end

        it 'selects 2024 form class ID' do
          expect(processor.send(:generate_2024_version?)).to be true
          expect(processor.send(:selected_form_class_id)).to eq('21-4142-2024')
        end

        it 'calls PDF filler with 2024 form ID' do
          expect(PdfFill::Filler).to receive(:fill_ancillary_form)
            .with(hash_including('veteranFullName' => anything), anything, '21-4142-2024')

          processor
        end

        it 'requires signature stamping when signature is present' do
          # Assuming the test data includes signature information
          expect(processor.send(:needs_signature_stamp?)).to be true
        end
      end
    end

    describe 'feature flag integration' do
      it 'correctly reads the team-specific template flag' do
        expect(Flipper).to receive(:enabled?).with(template_flag).and_return(true)

        processor.send(:generate_2024_version?)
      end

      it 'defaults to legacy when flag is not set' do
        allow(Flipper).to receive(:enabled?).with(template_flag).and_return(false)

        expect(processor.send(:generate_2024_version?)).to be false
      end
    end
  end
end
