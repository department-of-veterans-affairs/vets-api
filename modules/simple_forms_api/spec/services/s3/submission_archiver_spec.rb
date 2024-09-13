# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

# rubocop:disable RSpec/SubjectStub
RSpec.describe SimpleFormsApi::S3::SubmissionArchiver do
  let(:form_type) { '21-10210' }
  let(:form_data) { File.read("modules/simple_forms_api/spec/fixtures/form_json/vba_#{form_type.gsub('-', '_')}.json") }
  let(:submission) { create(:form_submission, :pending, form_type:, form_data:) }
  let(:benefits_intake_uuid) { submission.benefits_intake_uuid }
  let(:temp_directory_path) { Rails.root.join("tmp/#{benefits_intake_uuid}-random-letters-n-numbers/").to_s }

  before do
    allow(FormSubmission).to receive(:find_by).and_return(submission)
    allow(SecureRandom).to receive(:hex).and_return('random-letters-n-numbers')
    allow_any_instance_of(described_class).to receive(:build_submission_archive).and_call_original
    allow_any_instance_of(described_class).to receive(:log_info).and_call_original
  end

  describe '#initialize' do
    subject(:new_instance) { archive_submission_instance }

    let(:archive_submission_instance) { described_class.new(benefits_intake_uuid:) }

    it { is_expected.to have_received(:build_submission_archive) }
  end

  describe '#upload' do
    subject(:upload) { described_class.new(benefits_intake_uuid:).upload }

    xit { is_expected.to have_received(:log_info).with("Processing submission: #{benefits_intake_uuid}") }

    context 'when an error occurs'
  end

  describe '#download'
  describe '#cleanup'
  describe '.fetch_presigned_url'
  describe '.fetch_s3_submission'
  describe '.fetch_s3_archive'
end
# rubocop:enable RSpec/SubjectStub
