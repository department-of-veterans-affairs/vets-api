# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('rakelib', 'disability_compensation', 'report_submission_statuses')

RSpec.describe DisabilityCompensation::ReportSubmissionStatuses do
  include ActiveSupport::Testing::TimeHelpers

  subject(:perform) do
    ids = [
      excluded_non_bdd_submission.id,
      wanted_bdd_submission.id
    ]

    described_class.new.perform(
      consumer_klass, "#{described_class}::BddFilter",
      Time.current.to_i, ids
    )
  end

  before do
    travel_to time
    travel(-1.hour) do
      excluded_non_bdd_submission
      excluded_bdd_submission
      wanted_bdd_submission
    end
  end

  let(:excluded_non_bdd_submission) do
    create(
      :form526_submission
    ).tap do |submission|
      create(
        :form526_job_status,
        form526_submission: submission,
        job_class: 'SubmitForm526AllClaim',
        status: 'success'
      )
    end
  end

  let(:excluded_bdd_submission) do
    create(
      :form526_submission,
      :without_diagnostic_code
    ).tap do |submission|
      create(
        :form526_job_status,
        form526_submission: submission,
        job_class: 'SubmitForm526AllClaim',
        status: 'success'
      )
    end
  end

  let(:wanted_bdd_submission) do
    create(
      :form526_submission,
      :without_diagnostic_code
    ).tap do |submission|
      create(
        :form526_job_status,
        form526_submission: submission,
        job_class: 'SubmitForm526AllClaim',
        status: 'success'
      )
    end
  end

  describe 'using an echoing consumer' do
    let(:consumer_klass) { "#{described_class}::SpecConsumer" }
    let(:captured) { { key: String.new, consumed: [] } }
    let(:time) { '2026-02-10' }

    before do
      consumed = captured[:consumed]
      key = captured[:key]

      stub_const(
        'DisabilityCompensation::ReportSubmissionStatuses::SpecConsumer',
        Class.new do
          define_method(:initialize) do |filter, now|
            @filter = filter
            @now = now
          end

          define_method(:perform) do |each_submission|
            consumed.concat(each_submission.to_a)
            key << "#{@filter}-#{@now.to_i}.json"
            'ok'
          end
        end
      )
    end

    it 'passes only BDD submissions in provided ids to the consumer' do
      perform

      expect(captured).to eq(
        {
          key: 'disability_compensation/report_submission_statuses/bdd_filter-1770681600.json',
          consumed: [
            {
              'user_uuid' => wanted_bdd_submission.user_uuid,
              'saved_claim_id' => wanted_bdd_submission.saved_claim_id,
              'submitted_claim_id' => nil,
              'workflow_complete' => false,
              'created_at' => '2026-02-09T23:00:00.000Z',
              'updated_at' => '2026-02-09T23:00:00.000Z',
              'user_account_id' => wanted_bdd_submission.user_account_id,
              'backup_submitted_claim_id' => nil,
              'aasm_state' => 'unprocessed',
              'submit_endpoint' => nil,
              'backup_submitted_claim_status' => nil,
              'job_statuses' => [
                {
                  'job_id' => wanted_bdd_submission.form526_job_statuses.first.job_id,
                  'job_class' => 'SubmitForm526AllClaim',
                  'status' => 'success',
                  'error_class' => nil,
                  'error_message' => nil,
                  'updated_at' => '2026-02-09T23:00:00.000Z',
                  'bgjob_errors' => {}
                }
              ]
            }
          ]
        }
      )
    end
  end

  describe 'using the s3 consumer' do
    let(:consumer_klass) { "#{described_class}::S3Consumer" }
    let(:time) { '2026-02-10T06:43:49Z' }
    let(:aws_settings) do
      {
        access_key_id: 'fake_access_key_id',
        secret_access_key: 'fake_secret_access_key',
        region: 'us-gov-west-1',
        bucket: 'dsva-vetsgov-staging-reports'
      }
    end

    it 'correctly sources s3 settings' do
      vcr_name = 'disability_compensation/report_submission_statuses'
      vcr_options = {
        match_requests_on: %i[method uri],
        allow_unused_http_interactions: false
      }

      VCR.use_cassette(vcr_name, vcr_options) do
        with_settings(Settings.form526_export.aws, aws_settings) do
          expect { perform }.to raise_error(
            Aws::S3::Errors::AccessDenied
          )
        end
      end
    end
  end
end
