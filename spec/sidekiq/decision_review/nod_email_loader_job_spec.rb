# frozen_string_literal: true

require 'rails_helper'
require 'decision_review_v1/service'

RSpec.describe DecisionReview::NodEmailLoaderJob, type: :job do
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

  before do
    allow(Settings).to receive(:decision_review).and_return(double)
    allow(Settings.decision_review).to receive(:s3).and_return(double)
    allow(Settings.decision_review.s3).to receive(:bucket).and_return('bucket')
    allow(Settings.decision_review.s3).to receive(:region).and_return('region')
    allow(Settings.decision_review.s3).to receive(:aws_access_key_id).and_return('key')
    allow(Settings.decision_review.s3).to receive(:aws_secret_access_key).and_return('secret')

    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(s3_client).to receive(:get_object).with(any_args).and_return(get_s3_object)
  end

  describe 'perform' do
    context 'when csv with emails is loaded' do
      it 'queues additional jobs with the correct parameters' do
        expect(DecisionReview::NodSendEmailJob).not_to receive(:perform_async)
          .with('Email', anything, anything, anything)

        expect(DecisionReview::NodSendEmailJob).to receive(:perform_async)
          .with('email@test.com', template_id, { 'full_name' => 'John Vet' }, 1)
        expect(DecisionReview::NodSendEmailJob).to receive(:perform_async)
          .with('email2@test.com', template_id, { 'full_name' => 'Jane Doe' }, 2)
        expect(DecisionReview::NodSendEmailJob).to receive(:perform_async)
          .with('test@test.test', template_id, { 'full_name' => 'GI Joe' }, 3)

        subject.perform_async(file_name, template_id)
      end
    end

    context 'when an exception is thrown while loading the emails CSV' do
      before do
        allow(s3_client).to receive(:get_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'download failed'))
      end

      it 'aborts the job and does not queue any NodSendEmailJob jobs' do
        expect(DecisionReview::NodSendEmailJob).not_to receive(:perform_async)

        subject.perform_async(file_name, template_id)
      end
    end
  end
end
