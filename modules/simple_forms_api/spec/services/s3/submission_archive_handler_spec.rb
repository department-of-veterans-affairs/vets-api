# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::S3::SubmissionArchiveHandler do
  let(:form_type) { '21-10210' }
  let(:form_data) { File.read("modules/simple_forms_api/spec/fixtures/form_json/vba_#{form_type.tr('-', '_')}.json") }
  let(:submissions) { create_list(:form_submission, 4, :pending, form_type:, form_data:) }
  let(:benefits_intake_uuids) { submissions.map(&:benefits_intake_uuid) }

  describe '#initialize' do
    subject(:instance) { described_class.new(benefits_intake_uuids:) }

    context 'when no UUIDs are provided' do
      let(:benefits_intake_uuids) { [] }

      it 'raises a ParameterMissing exception' do
        expect { instance }.to raise_exception(Common::Exceptions::ParameterMissing, 'Missing parameter')
      end
    end
  end

  describe '#upload' do
    subject(:upload) { instance.upload }

    let(:instance) { described_class.new(benefits_intake_uuids:) }
    let(:presigned_url) { '/s3_presigned_url' }
    let(:archiver) { instance_double(SimpleFormsApi::S3::SubmissionArchiver) }

    before do
      allow(SimpleFormsApi::S3::SubmissionArchiver).to receive(:new).and_return(archiver)
      allow(archiver).to receive(:upload).and_return(presigned_url)
      allow(instance).to receive(:log_info).and_call_original
    end

    context 'when processing succeeds' do
      before { upload }

      it 'logs the correct status messages for each submission' do
        submissions.each_with_index do |submission, index|
          expect(instance).to have_received(:log_info).with(
            "Archiving submission: #{submission.benefits_intake_uuid} " \
            "##{index + 1} of #{submissions.size} total submissions"
          )
        end
      end
    end
  end
end
