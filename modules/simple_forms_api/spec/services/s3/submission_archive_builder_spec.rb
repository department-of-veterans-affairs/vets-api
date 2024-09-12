# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::S3::SubmissionArchiveBuilder do
  let(:form_id) { '21-10210' }
  let(:form_data) { File.read("modules/simple_forms_api/spec/fixtures/form_json/vba_#{form_id.gsub('-', '_')}.json") }
  let(:submission) { create(:form_submission, :pending, form_type: form_id, form_data:) }
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
  let(:archive_builder_instance) { described_class.new(benefits_intake_uuid:) }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow_any_instance_of(described_class).to receive(:assign_instance_variables).and_call_original
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
  end

  describe '#initialize' do
    subject(:new) { archive_builder_instance }

    let(:defaults) do
      {
        attachments: [],
        file_path: nil,
        include_json_archive: true,
        include_manifest: true,
        include_text_archive: true,
        metadata: {},
        parent_dir: 'vff-simple-forms'
      }
    end

    it { is_expected.to have_received(:assign_instance_variables).with(defaults) } # rubocop:disable RSpec/SubjectStub
  end

  describe '#run' do
    subject(:run) { archive_builder_instance.run }

    it 'completes successfully' do
      expect(run).to eq(Rails.root.join("tmp/#{benefits_intake_uuid}-random-letters-n-numbers/").to_s)
    end
  end
end
