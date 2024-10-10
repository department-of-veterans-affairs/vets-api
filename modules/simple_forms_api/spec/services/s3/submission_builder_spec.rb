# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::S3::SubmissionBuilder do
  let(:form_type) { '21-10210' }
  let(:form_doc) { "vba_#{form_type.gsub('-', '_')}.json" }
  let(:form_data) do
    fixture_path = Rails.root.join('modules', 'simple_forms_api', 'spec', 'fixtures', 'form_json', form_doc)
    File.read(fixture_path)
  end
  let(:created_at) { 3.years.ago }
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:, created_at:) }
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
  let(:builder_instance) { described_class.new(benefits_intake_uuid:) }
  let(:filler_double) { instance_double(SimpleFormsApi::PdfFiller) }
  let(:file_path) { '/tmp/vba_21_10210-random-letters-n-numbers-tmp.pdf' }
  let(:signature_date) { submission.created_at.in_time_zone('America/Chicago') }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
    allow(SimpleFormsApi::PdfFiller).to receive(:new).and_return(filler_double)
    allow(filler_double).to receive(:generate).and_return(file_path)
    allow_any_instance_of(described_class).to receive(:hydrate_submission).and_call_original
  end

  describe '#initialize' do
    subject(:new) { builder_instance }

    context 'when benefits_intake_uuid is valid' do
      it { is_expected.to have_received(:hydrate_submission) } # rubocop:disable RSpec/SubjectStub

      it 'generates a valid file_path' do
        expect(new.file_path).to include('/tmp/vba_21_10210-random-letters-n-numbers-tmp.pdf')
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
            'fileNumber' => '222773333',
            'zipCode' => '12345',
            'source' => 'VA Platform Digital Forms',
            'docType' => '21-10210',
            'businessLine' => 'CMP'
          }
        )
      end

      it 'sets the signature date properly' do
        new
        expect(SimpleFormsApi::PdfFiller).to(
          have_received(:new).with(a_hash_including(form: an_object_having_attributes(signature_date:)))
        )
      end

      context 'when the form is 20-10207 and has attachments' do
        let(:form_type) { '20-10207' }
        let(:form_doc) { 'vba_20_10207_with_supporting_documents.json' }

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
