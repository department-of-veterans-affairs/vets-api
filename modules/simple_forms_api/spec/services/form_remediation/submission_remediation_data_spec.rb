# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')
require 'simple_forms_api/form_remediation/error'
require 'simple_forms_api/form_remediation/configuration/vff_config'

RSpec.describe SimpleFormsApi::FormRemediation::SubmissionRemediationData do
  let(:form_type) { '20-10207' }
  let(:fixtures_path) { 'modules/simple_forms_api/spec/fixtures' }
  let(:form_data) { Rails.root.join(fixtures_path, 'form_json', 'vba_20_10207_with_supporting_documents.json').read }
  let(:file_path) { Rails.root.join(fixtures_path, 'pdfs', 'vba_20_10207-completed.pdf').to_s }
  let(:created_at) { 3.years.ago }
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:, created_at:) }
  let(:submission_attempt) { submission.form_submission_attempts.first }
  let(:benefits_intake_uuid) { submission_attempt.benefits_intake_uuid }
  let(:config) { SimpleFormsApi::FormRemediation::Configuration::VffConfig.new }
  let(:submission_instance) { described_class.new(id: benefits_intake_uuid, config:) }
  let(:filler) { instance_double(SimpleFormsApi::PdfFiller) }
  let(:attachments) { Array.new(5) { fixture_file_upload('doctors-note.pdf', 'application/pdf').path } }
  let(:metadata) do
    {
      'veteranFirstName' => 'John',
      'veteranLastName' => 'Veteran',
      'fileNumber' => '321540987',
      'zipCode' => '12345',
      'source' => 'VA Platform Digital Forms',
      'docType' => '20-10207',
      'businessLine' => 'CMP'
    }
  end
  let(:vba_20_10207_instance) { instance_double(SimpleFormsApi::VBA2010207, metadata:) }
  let(:signature_date) { submission.created_at.in_time_zone('America/Chicago') }

  before do
    allow(FormSubmissionAttempt).to receive(:find_by).with(benefits_intake_uuid:).and_return(submission_attempt)
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
    allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(filler)
    allow(filler).to receive(:generate).with(timestamp: submission.created_at).and_return(file_path)
    allow(SimpleFormsApi::VBA2010207).to receive(:new).and_return(vba_20_10207_instance)
    allow(vba_20_10207_instance).to(
      receive_messages(get_attachments: attachments, zip_code_is_us_based: true, 'signature_date=' => true)
    )
  end

  describe '#initialize' do
    subject(:new) { submission_instance }

    context 'when benefits_intake_uuid is valid' do
      before { new }

      it 'fetches the form submission data' do
        expect(FormSubmissionAttempt).to have_received(:find_by).with(benefits_intake_uuid:)
      end

      it 'sets the form submission data' do
        expect(new.submission).to be(submission)
      end

      it 'sets attachments to empty array' do
        expect(new.attachments).to eq([])
      end
    end

    context 'when benefits_intake_uuid is nil' do
      let(:benefits_intake_uuid) { nil }

      it 'throws an error' do
        expect do
          new
        end.to raise_exception(SimpleFormsApi::FormRemediation::Error,
                               a_string_including('No benefits_intake_uuid was provided'))
      end
    end

    context 'when benefits_intake_uuid is missing' do
      let(:submission_instance) { described_class.new(stuff: 'thangs', config:) }

      it 'throws an error' do
        expect { new }.to raise_exception(ArgumentError, 'missing keyword: :id')
      end
    end

    context 'when config is missing' do
      let(:submission_instance) { described_class.new(stuff: 'thangs', id: benefits_intake_uuid) }

      it 'throws an error' do
        expect { new }.to raise_exception(ArgumentError, 'missing keyword: :config')
      end
    end

    context 'when the form submission is not found' do
      before { allow(FormSubmissionAttempt).to receive(:find_by).and_return(nil) }

      it 'throws an error' do
        expect do
          new
        end.to raise_exception(SimpleFormsApi::FormRemediation::Error,
                               a_string_including('Submission was not found or invalid'))
      end
    end

    context 'when benefits_intake_uuid is invalid' do
      let(:benefits_intake_uuid) { 'complete-nonsense' }

      before { allow(FormSubmissionAttempt).to receive(:find_by).and_call_original }

      it 'raises an error' do
        expect do
          new
        end.to raise_exception(SimpleFormsApi::FormRemediation::Error,
                               a_string_including('Submission was not found or invalid'))
      end
    end

    context 'when the associated form submission is not VFF in nature' do
      let(:submission) { create(:form_submission, :pending, form_type: '12-34567', form_data:) }
      let(:error_message) { 'Only VFF forms are supported' }

      it 'raises an error' do
        expect { new }.to(
          raise_exception(SimpleFormsApi::FormRemediation::Error, a_string_including(error_message))
        )
      end
    end
  end

  describe '#hydrate!' do
    subject(:hydrated) { submission_instance.hydrate! }

    context 'when benefits_intake_uuid is valid' do
      it 'generates a valid file_path' do
        expect(hydrated.file_path).to include(file_path)
      end

      it 'generates a valid submission' do
        expect(hydrated.submission).to be(submission)
      end

      it 'defaults to an empty array for attachments' do
        expect(hydrated.attachments).to eq(attachments)
      end

      it 'generates valid metadata' do
        expect(hydrated.metadata).to eq(metadata)
      end

      it 'sets the signature date properly' do
        hydrated
        expect(vba_20_10207_instance).to have_received(:signature_date=).with(signature_date)
      end

      context 'when the form is 20-10207' do
        it 'generates a valid array of attachments' do
          expect(hydrated.attachments).to eq(attachments)
        end
      end

      context 'when the form is not 20-10207' do
        let(:form_type) { '21-10210' }
        let(:form_data) { Rails.root.join(fixtures_path, 'form_json', 'vba_21_10210.json').read }
        let(:vba_21_10210_instance) { instance_double(SimpleFormsApi::VBA2110210, metadata:) }

        before do
          allow(SimpleFormsApi::VBA2110210).to receive(:new).and_return(vba_20_10207_instance)
          allow(vba_21_10210_instance).to receive_messages(zip_code_is_us_based: true)
        end

        it 'defaults to an empty array for attachments' do
          expect(hydrated.attachments).to eq([])
        end
      end
    end
  end
end
