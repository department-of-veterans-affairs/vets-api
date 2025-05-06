# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FormValidation do
  let(:test_class) do
    Class.new do
      include ActiveModel::Model
      include FormValidation
    end
  end

  let(:form) { VetsJsonSchema::EXAMPLES['10-10CG'].clone.to_json }
  let(:parsed_form) { JSON.parse(form) }
  let(:schema) { VetsJsonSchema::SCHEMAS['10-10CG'] }
  let(:max_attempts) { nil }

  let(:instance) { test_class.new }

  describe '#validate_form_with_retries' do
    context 'no validation errors' do
      before do
        allow(JSON::Validator).to receive(:fully_validate).and_return([])
      end

      it 'returns true' do
        expect(Rails.logger).not_to receive(:info)
          .with("Form validation in #{instance} succeeded on attempt 1/3")

        expect(instance.validate_form_with_retries(schema, parsed_form)).to eq []
      end
    end

    context 'validation errors' do
      let(:schema_errors) { [{ fragment: 'error' }] }

      context 'when JSON:Validator.fully_validate returns errors' do
        before do
          allow(JSON::Validator).to receive(:fully_validate).and_return(schema_errors)
        end

        it 'adds validation errors to the form' do
          expect(JSON::Validator).not_to receive(:fully_validate_schema)

          expect(Rails.logger).not_to receive(:info)
            .with("Form validation in #{instance} succeeded on attempt 1/3")

          expect(instance.validate_form_with_retries(schema, parsed_form)).not_to be_empty
        end
      end

      context 'when JSON:Validator.fully_validate throws an exception' do
        let(:exception_text) { 'Some exception' }
        let(:exception) { StandardError.new(exception_text) }

        context '3 times' do
          let(:schema) { 'schema_content' }

          before do
            allow(JSON::Validator).to receive(:fully_validate).and_raise(exception)
          end

          it 'logs exceptions and raises exception' do
            expect(Rails.logger).to receive(:warn)
              .with("Retrying form validation in #{instance.class} due to error: " \
                    "#{exception_text} (Attempt 1/3)").once
            expect(Rails.logger).not_to receive(:info)
              .with("Form validation in #{instance.class} succeeded on attempt 1/3")
            expect(Rails.logger).to receive(:warn)
              .with("Retrying form validation in #{instance.class} due to error: " \
                    "#{exception_text} (Attempt 2/3)").once
            expect(Rails.logger).to receive(:warn)
              .with("Retrying form validation in #{instance.class} due to error: " \
                    "#{exception_text} (Attempt 3/3)").once
            expect(Rails.logger).to receive(:error)
              .with("Error during form validation in #{instance.class} after " \
                    'maximum retries', { error: exception.message,
                                         backtrace: anything })

            expect(PersonalInformationLog).to receive(:create).with(
              data: { schema:,
                      parsed_form:,
                      params: { errors_as_objects: true } },
              error_class: "#{instance.class} FormValidationError"
            )

            expect do
              instance.validate_form_with_retries(schema, parsed_form)
            end.to raise_error(exception.class, exception.message)
          end
        end

        context '1 time but succeeds after retrying' do
          before do
            # Throws exception the first time, returns empty array on subsequent calls
            call_count = 0
            allow(JSON::Validator).to receive(:fully_validate).and_wrap_original do
              call_count += 1
              if call_count == 1
                raise exception
              else
                []
              end
            end
          end

          it 'logs exception and validates succesfully after the retry' do
            expect(Rails.logger).to receive(:warn)
              .with("Retrying form validation in #{instance.class} due to error: " \
                    "#{exception_text} (Attempt 1/3)").once
            expect(Rails.logger).to receive(:info)
              .with("Form validation in #{instance.class} succeeded on attempt 2/3").once

            expect(instance.validate_form_with_retries(schema, parsed_form)).to eq []
          end
        end

        context 'passing custom max_attempts value' do
          let(:schema) { 'schema_content' }
          let(:max_attempts) { 1 }

          before do
            allow(JSON::Validator).to receive(:fully_validate).and_raise(exception)
          end

          it 'logs exceptions and raises exception' do
            expect(Rails.logger).to receive(:error)
              .with("Error during form validation in #{instance.class} after " \
                    'maximum retries', { error: exception.message,
                                         backtrace: anything })

            expect(PersonalInformationLog).to receive(:create).with(
              data: { schema:,
                      parsed_form:,
                      params: { errors_as_objects: true } },
              error_class: "#{instance.class} FormValidationError"
            )

            expect do
              instance.validate_form_with_retries(schema, parsed_form, max_attempts)
            end.to raise_error(exception.class, exception.message)
          end
        end
      end
    end
  end
end
