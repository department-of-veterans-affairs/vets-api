# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::CaregiversAssistanceClaim do
  describe 'schema' do
    it 'is deep frozen' do
      expect do
        VetsJsonSchema::SCHEMAS['10-10CG']['title'] = 'foo'
      end.to raise_error(FrozenError)

      expect(VetsJsonSchema::SCHEMAS['10-10CG']['title']).to eq(
        'Application for Comprehensive Assistance for Family Caregivers Program (10-10CG)'
      )
    end
  end

  describe '#to_pdf' do
    let(:claim) { build(:caregivers_assistance_claim) }

    it 'renders unicode chars correctly' do
      unicode = 'name’'
      claim.parsed_form['veteran']['fullName']['first'] = unicode
      pdf_file = claim.to_pdf(sign: true)

      expect(PdfFill::Filler::UNICODE_PDF_FORMS.get_fields(pdf_file).map(&:value).find do |val|
        val == unicode
      end).to eq(unicode)

      File.delete(pdf_file)
    end

    it 'calls PdfFill::Filler#fill_form' do
      expect(PdfFill::Filler).to receive(:fill_form).with(claim, claim.guid).once.and_return(:expected_file_paths)
      expect(claim.to_pdf).to eq(:expected_file_paths)
    end

    context 'passes arguments to PdfFill::Filler#fill_form' do
      it 'converts to pdf with the file name alone' do
        expect(PdfFill::Filler).to receive(
          :fill_form
        ).with(
          claim,
          'my_other_filename'
        ).once.and_return(:expected_file_paths)

        # Calling with only filename
        claim.to_pdf('my_other_filename')
      end

      it 'converts to pdf with the options alone' do
        expect(PdfFill::Filler).to receive(
          :fill_form
        ).with(
          claim,
          claim.guid,
          save: true
        ).once.and_return(:expected_file_paths)

        # Calling with only options
        claim.to_pdf(save: true)
      end

      it 'converts to pdf with the filename and options' do
        expect(PdfFill::Filler).to receive(
          :fill_form
        ).with(
          claim,
          'my_other_filename',
          save: false
        ).once.and_return(:expected_file_paths)

        # Calling with filename and options
        claim.to_pdf('my_other_filename', save: false)
      end
    end

    context 'errors' do
      let(:error_message) { 'fill form error' }

      before do
        allow(PdfFill::Filler).to receive(:fill_form).and_raise(StandardError, error_message)
        allow(Rails.logger).to receive(:error)
        allow(PersonalInformationLog).to receive(:create)
      end

      it 'logs the error, creates a PersonalInformationLog, and raises the error' do
        expect(Rails.logger).to receive(:error).with("Failed to generate PDF: #{error_message}")
        expect(PersonalInformationLog).to receive(:create).with(
          data: { form: claim.parsed_form, file_name: claim.guid },
          error_class: '1010CGPdfGenerationError'
        )
        expect { claim.to_pdf }.to raise_error(StandardError, error_message)
      end
    end
  end

  describe 'validations' do
    let(:claim) { build(:caregivers_assistance_claim) }

    before do
      allow(Flipper).to receive(:enabled?).and_call_original
    end

    context 'caregiver_retry_form_validation disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:caregiver_retry_form_validation).and_return(false)
      end

      context 'no validation errors' do
        before do
          allow(JSON::Validator).to receive(:fully_validate).and_return([])
        end

        it 'returns true' do
          expect(claim.validate).to eq true
        end
      end

      context 'validation errors' do
        it 'calls the parent method when the toggle is off' do
          allow(claim).to receive(:form_matches_schema).and_call_original

          claim.validate

          expect(claim).to have_received(:form_matches_schema)
        end
      end
    end

    context 'caregiver_retry_form_validation enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:caregiver_retry_form_validation).and_return(true)
      end

      context 'no validation errors' do
        before do
          allow(JSON::Validator).to receive(:fully_validate).and_return([])
        end

        it 'returns true' do
          expect(Rails.logger).not_to receive(:info)
            .with('Form validation succeeded on attempt 1/3')

          expect(claim.validate).to eq true
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
              .with('Form validation succeeded on attempt 1/3')

            claim.validate
            expect(claim.errors.full_messages).not_to be_empty
          end
        end

        context 'when JSON:Validator.fully_validate throws an exception' do
          let(:exception_text) { 'Some exception' }
          let(:exception) { StandardError.new(exception_text) }

          context '3 times' do
            let(:schema) { 'schema_content' }

            before do
              allow(VetsJsonSchema::SCHEMAS).to receive(:[]).and_return(schema)
              allow(JSON::Validator).to receive(:fully_validate).and_raise(exception)
            end

            it 'logs exceptions and raises exception' do
              expect(Rails.logger).to receive(:warn)
                .with("Retrying form validation due to error: #{exception_text} (Attempt 1/3)").once
              expect(Rails.logger).not_to receive(:info)
                .with('Form validation succeeded on attempt 1/3')
              expect(Rails.logger).to receive(:warn)
                .with("Retrying form validation due to error: #{exception_text} (Attempt 2/3)").once
              expect(Rails.logger).to receive(:warn)
                .with("Retrying form validation due to error: #{exception_text} (Attempt 3/3)").once

              expect(Rails.logger).to receive(:error)
                .with('Error during form validation after maximimum retries', { error: exception.message,
                                                                                backtrace: anything, schema: })

              expect(PersonalInformationLog).to receive(:create).with(
                data: { schema: schema,
                        parsed_form: claim.parsed_form,
                        params: { errors_as_objects: true } },
                error_class: 'SavedClaim FormValidationError'
              )

              expect { claim.validate }.to raise_error(exception.class, exception.message)
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
                .with("Retrying form validation due to error: #{exception_text} (Attempt 1/3)").once
              expect(Rails.logger).to receive(:info)
                .with('Form validation succeeded on attempt 2/3').once

              expect(claim.validate).to eq true
            end
          end
        end
      end
    end
  end

  describe '#process_attachments!' do
    it 'raises a NotImplementedError' do
      expect { subject.process_attachments! }.to raise_error(NotImplementedError)
    end
  end

  describe '#regional_office' do
    it 'returns empty array' do
      expect(subject.regional_office).to eq([])
    end
  end

  describe '#form_subjects' do
    it 'does not consider signAsRepresentative a form_subject' do
      claim_1 = described_class.new(form: {
        veteran: {},
        signAsRepresentative: true
      }.to_json)
      expect(claim_1.form_subjects).to eq(%w[veteran])
    end

    it 'returns a list of subjects present in #parsed_form' do
      claim_1 = described_class.new(form: {
        veteran: {}
      }.to_json)
      expect(claim_1.form_subjects).to eq(%w[veteran])

      claim_2 = described_class.new(form: {
        veteran: {},
        primaryCaregiver: {}
      }.to_json)
      expect(claim_2.form_subjects).to eq(%w[veteran primaryCaregiver])

      claim_3 = described_class.new(form: {
        veteran: {},
        secondaryCaregiverOne: {}
      }.to_json)
      expect(claim_3.form_subjects).to eq(%w[veteran secondaryCaregiverOne])

      claim_4 = described_class.new(form: {
        veteran: {},
        primaryCaregiver: {},
        secondaryCaregiverOne: {}
      }.to_json)
      expect(claim_4.form_subjects).to eq(%w[veteran primaryCaregiver secondaryCaregiverOne])

      claim_5 = described_class.new(form: {
        veteran: {},
        primaryCaregiver: {},
        secondaryCaregiverOne: {},
        secondaryCaregiverTwo: {}
      }.to_json)
      expect(claim_5.form_subjects).to eq(%w[veteran primaryCaregiver secondaryCaregiverOne secondaryCaregiverTwo])
    end

    context 'when no subjects are present' do
      it 'returns a an empty array' do
        expect(subject.form_subjects).to eq([])
      end
    end
  end

  describe '#veteran_data' do
    it 'returns the veteran\'s data from the form as a hash' do
      subjects_data = { 'myName' => 'Veteran' }
      subject = described_class.new(
        form: {
          'veteran' => subjects_data
        }.to_json
      )

      expect(subject.veteran_data).to eq(subjects_data)
    end

    context 'when no data present' do
      it 'returns nil' do
        expect(subject.veteran_data).to eq(nil)
      end
    end
  end

  describe '#primary_caregiver_data' do
    it 'returns the veteran\'s data from the form as a hash' do
      subjects_data = { 'myName' => 'Primary Caregiver' }

      subject = described_class.new(
        form: {
          'primaryCaregiver' => subjects_data
        }.to_json
      )

      expect(subject.primary_caregiver_data).to eq(subjects_data)
    end

    context 'when no data present' do
      it 'returns nil' do
        expect(subject.primary_caregiver_data).to eq(nil)
      end
    end
  end

  describe '#secondary_caregiver_one_data' do
    it 'returns the veteran\'s data from the form as a hash' do
      subjects_data = { 'myName' => 'Secondary Caregiver I' }

      subject = described_class.new(
        form: {
          'secondaryCaregiverOne' => subjects_data
        }.to_json
      )

      expect(subject.secondary_caregiver_one_data).to eq(subjects_data)
    end

    context 'when no data present' do
      it 'returns nil' do
        expect(subject.secondary_caregiver_one_data).to eq(nil)
      end
    end
  end

  describe '#destroy_attachment' do
    let(:claim) { create(:caregivers_assistance_claim) }
    let(:attachment) { create(:form1010cg_attachment, :with_attachment) }

    context 'when attachment id is not present' do
      it 'does nothing' do
        claim.destroy!
      end
    end

    context 'when attachment exists' do
      before do
        claim.parsed_form['poaAttachmentId'] = attachment.guid
      end

      it 'destroys the attachment' do
        file = double
        expect_any_instance_of(Form1010cg::Attachment).to receive(:get_file).and_return(file)
        expect(file).to receive(:delete)

        claim.destroy!
        expect(Form1010cg::Attachment.exists?(id: attachment.id)).to eq(false)
      end
    end

    context 'when the attachment doesnt exist' do
      before do
        claim.parsed_form['poaAttachmentId'] = SecureRandom.uuid
      end

      it 'does nothing' do
        claim.destroy!
      end
    end
  end

  describe '#secondary_caregiver_two_data' do
    it 'returns the veteran\'s data from the form as a hash' do
      subjects_data = { 'myName' => 'Secondary Caregiver II' }

      subject = described_class.new(
        form: {
          'secondaryCaregiverTwo' => subjects_data
        }.to_json
      )

      expect(subject.secondary_caregiver_two_data).to eq(subjects_data)
    end

    context 'when no data present' do
      it 'returns nil' do
        expect(subject.secondary_caregiver_two_data).to eq(nil)
      end
    end
  end
end
