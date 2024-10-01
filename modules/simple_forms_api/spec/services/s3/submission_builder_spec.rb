# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::S3::SubmissionBuilder do
  let(:form_type) { '20-10207' }
  let(:fixtures_path) { 'modules/simple_forms_api/spec/fixtures' }
  let(:form_data) { Rails.root.join(fixtures_path, 'form_json', 'vba_20_10207_with_supporting_documents.json').read }
  let(:file_path) { Rails.root.join(fixtures_path, 'pdfs', 'vba_20_10207-completed.pdf').to_s }
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:) }
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
  let(:builder_instance) { described_class.new(id: benefits_intake_uuid) }
  let(:filler) { instance_double(SimpleFormsApi::PdfFiller) }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
    allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(filler)
    allow(filler).to receive(:generate).with(timestamp: submission.created_at).and_return(file_path)
  end

  describe '#initialize' do
    subject(:new) { builder_instance }

    context 'when benefits_intake_uuid is valid' do
      it 'generates a valid file_path' do
        expect(new.file_path).to include(file_path)
      end

      it 'generates a valid submission' do
        expect(new.submission).to be(submission)
      end

      it 'defaults to an empty array for attachments' do
        expect(new.attachments).to eq([])
      end

      it 'generates valid metadata' do
        expect(new.metadata).to eq(
          {
            'veteranFirstName' => 'John',
            'veteranLastName' => 'Veteran',
            'fileNumber' => '321540987',
            'zipCode' => '12345',
            'source' => 'VA Platform Digital Forms',
            'docType' => '20-10207',
            'businessLine' => 'CMP'
          }
        )
      end

      context 'when the form is 20-10207 and has attachments' do
        it 'generates a valid array of attachments' do
          expect(new.attachments).to eq([])
        end
      end
    end

    context 'when benefits_intake_uuid is nil' do
      let(:benefits_intake_uuid) { nil }

      before { allow(FormSubmission).to receive(:find_by).and_call_original }

      it 'raises an error' do
        expect { new }.to raise_exception('No benefits_intake_uuid was provided')
      end
    end

    context 'when benefits_intake_uuid is invalid' do
      let(:benefits_intake_uuid) { 'complete-nonsense' }

      before { allow(FormSubmission).to receive(:find_by).and_call_original }

      it 'raises an error' do
        expect { new }.to raise_exception('Submission was not found or invalid')
      end
    end

    context 'when the associated form submission is not VFF in nature' do
      let(:submission) { create(:form_submission, :pending, form_type: '12-34567', form_data:) }

      it 'raises an error' do
        expect { new }.to raise_exception('Submission cannot be built: Only VFF forms are supported')
      end
    end
  end
end
