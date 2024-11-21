# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DecisionReviews::NodEmailLoaderJob, type: :job do
  subject { described_class }

  around do |example|
    Sidekiq::Testing.inline!(&example)
  end

  let(:template_id) { Faker::Internet.uuid }

  let(:file_name) { 'path/csv_file.csv' }
  let(:csv_data) do
    StringIO.new("Email,Full Name\nemail@test.com,John Vet\nemail2@test.com,Jane Doe\ntest@test.test,GI Joe\n")
  end
  let(:get_s3_object) { Aws::S3::Types::GetObjectOutput.new(body: csv_data) }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_config) { { bucket: 'bucket', region: 'region', aws_access_key_id: 'key', aws_secret_access_key: 'secret' } }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(s3_client).to receive(:get_object).with(any_args).and_return(get_s3_object)
  end

  describe 'perform' do
    context 'when csv with emails is loaded' do
      it 'queues additional jobs with the correct parameters' do
        expect(DecisionReviews::NodSendEmailJob).not_to receive(:perform_async)
          .with('Email', anything, anything, anything)

        expect(DecisionReviews::NodSendEmailJob).to receive(:perform_async)
          .with('email@test.com', template_id, { 'full_name' => 'John Vet' }, 1)
        expect(DecisionReviews::NodSendEmailJob).to receive(:perform_async)
          .with('email2@test.com', template_id, { 'full_name' => 'Jane Doe' }, 2)
        expect(DecisionReviews::NodSendEmailJob).to receive(:perform_async)
          .with('test@test.test', template_id, { 'full_name' => 'GI Joe' }, 3)

        subject.perform_async(file_name, template_id, s3_config)
      end
    end

    context 'when an exception is thrown while loading the emails CSV' do
      before do
        allow(s3_client).to receive(:get_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'download failed'))
      end

      it 'aborts the job and does not queue any NodSendEmailJob jobs' do
        expect(DecisionReviews::NodSendEmailJob).not_to receive(:perform_async)

        subject.perform_async(file_name, template_id, s3_config)
      end
    end
  end
end
