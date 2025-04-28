# frozen_string_literal: true

require 'rails_helper'
require 'rake'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe 'simple_forms_api:remediate_0781_only_submissions', type: :task do
  let(:submission) do
    instance_double(
      Form526Submission,
      id: '123',
      created_at: Time.zone.local(2020, 1, 1, 12, 0, 0),
      submitted_claim_id: 'abc',
      form_to_json: '{"form0781": {"foo": "bar"}}'
    )
  end
  let(:pdf_path) { '/tmp/fake.pdf' }
  let(:s3_url) { 'https://example.com/fake.pdf' }
  let(:pdf_stamper) { instance_double(PDFUtilities::DatestampPdf, run: pdf_path) }

  before do
    load File.expand_path('../../lib/tasks/remediate_0781_only_submissions.rake', __dir__)
    Rake::Task.define_task(:environment)

    task_instance = Rake::Task['simple_forms_api:remediate_0781_only_submissions']

    task_instance.define_singleton_method(:s3_client) do
      Aws::S3::Resource.new
    end
    allow(PDFUtilities::DatestampPdf).to receive(:new).and_return(pdf_stamper)
  end

  after do
    RSpec::Mocks.verify
    RSpec::Mocks.teardown
    Rake::Task['simple_forms_api:remediate_0781_only_submissions'].reenable
  end

  context 'when processing a submission' do
    it 'processes a single submission id and outputs a presigned url' do
      allow(Form526Submission).to receive(:find).and_return(submission)
      allow(JSON).to receive(:parse).and_call_original
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(pdf_path)
      allow(Rails.logger).to receive(:error)

      s3_obj = instance_double(Aws::S3::Object)
      s3_bucket = instance_double(Aws::S3::Bucket)
      s3_resource = instance_double(Aws::S3::Resource)

      allow(s3_obj).to receive_messages(exists?: false, presigned_url: s3_url, upload_file: true)
      allow(s3_bucket).to receive(:object).and_return(s3_obj)
      allow(s3_resource).to receive(:bucket).and_return(s3_bucket)
      allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)

      expect { Rake::Task['simple_forms_api:remediate_0781_only_submissions'].invoke('123') }
        .to output(/Uploaded: remediation/).to_stdout
    end

    it 'reports not found for missing submission' do
      allow(Form526Submission).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
      expect { Rake::Task['simple_forms_api:remediate_0781_only_submissions'].invoke('999') }
        .to output(/Not found: 999/).to_stdout
    end

    it 'reports error for unexpected exception' do
      allow(Form526Submission).to receive(:find).and_raise(StandardError, 'fail')
      allow(Rails.logger).to receive(:error)
      expect(Rails.logger).to receive(:error).with(/Error processing submission_id: 999: fail/)
      expect { Rake::Task['simple_forms_api:remediate_0781_only_submissions'].invoke('999') }
        .to output(/Error: 999: fail/).to_stdout
    end
  end

  context 'when PDF already exists' do
    it 'skips if PDF already exists in S3' do
      allow(Form526Submission).to receive(:find).and_return(submission)
      allow(JSON).to receive(:parse).and_call_original
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_return(pdf_path)
      allow(Rails.logger).to receive(:error)

      s3_obj = instance_double(Aws::S3::Object)
      s3_bucket = instance_double(Aws::S3::Bucket)
      s3_resource = instance_double(Aws::S3::Resource)

      allow(s3_obj).to receive_messages(exists?: true, presigned_url: s3_url, upload_file: true)
      allow(s3_bucket).to receive(:object).and_return(s3_obj)
      allow(s3_resource).to receive(:bucket).and_return(s3_bucket)
      allow(Aws::S3::Resource).to receive(:new).and_return(s3_resource)

      expect { Rake::Task['simple_forms_api:remediate_0781_only_submissions'].invoke('123') }
        .to output(/Skipped \(exists\): remediation/).to_stdout
    end
  end
end
