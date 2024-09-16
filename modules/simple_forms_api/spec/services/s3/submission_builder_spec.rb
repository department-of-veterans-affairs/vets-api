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
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:) }
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
  let(:builder_instance) { described_class.new(benefits_intake_uuid:) }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
    allow_any_instance_of(described_class).to receive(:rebuild_submission).and_call_original
  end

  describe '#initialize' do
    subject(:new) { builder_instance }

    context 'when benefits_intake_uuid is valid' do
      it { is_expected.to have_received(:rebuild_submission) } # rubocop:disable RSpec/SubjectStub

      it 'generates a valid file_path' do
        expect(new.file_path).to include('/tmp/vba_21_10210-random-letters-n-numbers-tmp.pdf')
      end

      it 'generates a valid submission' do
        expect(new.submission).to be(submission)
      end

      it 'generates an empty array for attachments' do
        expect(new.attachments).to eq([])
      end

      context 'when the form is 20-10207 and has attachments' do
        let(:form_type) { '20-10207' }
        let(:form_doc) { 'vba_20_10207_with_supporting_documents.json' }

        it 'generates a valid array of attachments' do
          expect(new.attachments).to eq([])
        end
      end
    end

    context 'when benefits_intake_uuid is invalid'
    context 'when form submission is not VFF in nature'
  end
end
