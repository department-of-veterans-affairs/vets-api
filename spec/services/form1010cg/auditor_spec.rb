# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Auditor do
  let(:subject) do
    described_class.instance
  end

  before(:all) do
    # StatsD is configured to use Rails.logger in order to output the stats that are being incremented in our app.
    # Since our methods calls StatsD#increment, it will create a log output using Rails.logger.
    #
    # In order to set expectations on Rails.logger for **only** what our test suite is concerned with, we'll need to
    # disconnect the Rails.logger form StatsD and reconnect it after our test suite is completed.
    @_statsd_logger = StatsD.backend
    StatsD.backend  = nil
  end

  after(:all) do
    StatsD.backend = @_statsd_logger
  end

  it 'is a singleton' do
    expect(described_class.ancestors).to include(Singleton)
  end

  describe ':metrics' do
    it 'provides StatsD metric values' do
      expect(
        described_class.metrics.submission.attempt
      ).to eq('api.form1010cg.submission.attempt')
      expect(
        described_class.metrics.submission.success
      ).to eq('api.form1010cg.submission.success')
      expect(
        described_class.metrics.submission.failure.client.data
      ).to eq('api.form1010cg.submission.failure.client.data')
      expect(
        described_class.metrics.submission.failure.client.qualification
      ).to eq('api.form1010cg.submission.failure.client.qualification')
      expect(
        described_class.metrics.pdf_download
      ).to eq('api.form1010cg.pdf_download')
    end
  end

  describe '#record_submission_attempt' do
    context 'increments' do
      it 'api.form1010cg.submission.attempt' do
        expect(StatsD).to receive(:increment).with('api.form1010cg.submission.attempt')
        subject.record_submission_attempt
      end
    end

    context 'logs' do
      it 'nothing' do
        expect(Rails.logger).not_to receive(:info)
        subject.record_submission_attempt
      end
    end
  end

  describe '#record_submission_success' do
    context 'requires' do
      it 'claim_guid:, carma_case_id:, metadata:, attachments:, attachments_job_id:' do
        expect { subject.record_submission_success }.to raise_error(ArgumentError) do |e|
          expect(e.message).to eq(
            'missing keywords: claim_guid, carma_case_id, metadata, attachments, attachments_job_id'
          )
        end
      end
    end

    context 'increments' do
      it 'api.form1010cg.submission.success' do
        expected_context = {
          claim_guid: 'uuid-123',
          carma_case_id: 'CASE_123',
          metadata: {},
          attachments: {},
          attachments_job_id: 'abc123'
        }

        expect(StatsD).to receive(:increment).with('api.form1010cg.submission.success')
        subject.record_submission_success(expected_context)
      end
    end

    context 'logs' do
      it '[Form 10-10CG] Submission Successful' do
        expected_message = '[Form 10-10CG] Submission Successful'
        provided_context = {
          claim_guid: 'uuid-123',
          carma_case_id: 'CASE_123',
          metadata: {
            'claimGuid' => 'uuid-123',
            'veteran' => { 'icn' => nil, 'isVeteran' => false },
            'primaryCaregiver' => { 'icn' => nil },
            'secondaryCaregiverOne' => { 'icn' => nil },
            'secondaryCaregiverTwo' => nil
          },
          attachments: {
            'has_errors' => false,
            'data' => [
              {
                'id' => '0123ABC',
                'carma_case_id' => 'CASE_123',
                'veteran_name' => {
                  'first' => 'First',
                  'last' => 'Last'
                },
                'file_path' => 'tmp/pdfs/10-10CG_uuid-123.pdf',
                'document_type' => '10-10CG',
                'document_date' => '2020-01-01'
              },
              {
                'id' => '0123ABC',
                'carma_case_id' => 'CASE_123',
                'veteran_name' => {
                  'first' => 'First',
                  'last' => 'Last'
                },
                'file_path' => 'tmp/pdfs/POA_uuid-123.pdf',
                'document_type' => 'POA',
                'document_date' => '2020-01-01'
              }
            ]
          },
          attachments_job_id: '12345abcdef'
        }

        logged_context = {
          claim_guid: provided_context[:claim_guid],
          carma_case_id: provided_context[:carma_case_id],
          metadata: provided_context[:metadata],
          attachments: {
            'has_errors' => false,
            'data' => [
              {
                'id' => '0123ABC',
                'carma_case_id' => 'CASE_123',
                'veteran_name' => '[FILTERED]',
                'file_path' => 'tmp/pdfs/10-10CG_uuid-123.pdf',
                'document_type' => '10-10CG',
                'document_date' => '2020-01-01'
              },
              {
                'id' => '0123ABC',
                'carma_case_id' => 'CASE_123',
                'veteran_name' => '[FILTERED]',
                'file_path' => 'tmp/pdfs/POA_uuid-123.pdf',
                'document_type' => 'POA',
                'document_date' => '2020-01-01'
              }
            ]
          },
          attachments_job_id: provided_context[:attachments_job_id]
        }

        expect(Rails.logger).to receive(:info).with(expected_message, logged_context)
        subject.record_submission_success(provided_context)
      end
    end
  end

  describe '#record_submission_failure_client_data' do
    context 'requires' do
      it 'errors:' do
        expect { subject.record_submission_failure_client_data }.to raise_error(ArgumentError) do |e|
          expect(e.message).to eq('missing keyword: errors')
        end

        expect { subject.record_submission_failure_client_data(errors: %w[error1 error2]) }.not_to raise_error
      end
    end

    context 'accepts' do
      it 'claim_guid:' do
        expect do
          subject.record_submission_failure_client_data(errors: %w[error1 error2], claim_guid: 'uuid-1234')
        end.not_to raise_error
      end
    end

    context 'increments' do
      it 'api.form1010cg.submission.failure.client.data' do
        expected_context = { errors: %w[error1 error2], claim_guid: 'uuid-123' }

        expect(StatsD).to receive(:increment).with('api.form1010cg.submission.failure.client.data')
        subject.record_submission_failure_client_data(expected_context)
      end
    end

    context 'logs' do
      it '[Form 10-10CG] Submission Failed: invalid data provided by client' do
        expected_message = '[Form 10-10CG] Submission Failed: invalid data provided by client'
        expected_context = { errors: %w[error1 error2], claim_guid: 'uuid-123' }

        expect(Rails.logger).to receive(:info).with(expected_message, expected_context)

        subject.record_submission_failure_client_data(expected_context)
      end
    end
  end

  describe '#record_submission_failure_client_qualification' do
    context 'requires' do
      it 'claim_guid:, veteran_name:' do
        expect { subject.record_submission_failure_client_qualification }.to raise_error(ArgumentError) do |e|
          expect(e.message).to eq('missing keyword: claim_guid')
        end
      end
    end

    context 'increments' do
      it 'api.form1010cg.submission.failure.client.data' do
        expected_context = { claim_guid: 'uuid-123' }

        expect(StatsD).to receive(:increment).with('api.form1010cg.submission.failure.client.qualification')
        subject.record_submission_failure_client_qualification(expected_context)
      end
    end

    context 'logs' do
      it '[Form 10-10CG] Submission Failed: qualifications not met' do
        expected_message = '[Form 10-10CG] Submission Failed: qualifications not met'
        expected_context = { claim_guid: 'uuid-123' }

        expect(Rails.logger).to receive(:info).with(expected_message, expected_context)

        subject.record_submission_failure_client_qualification(expected_context)
      end
    end
  end

  describe '#record_pdf_download' do
    context 'increments' do
      it 'api.form1010cg.submission.failure.client.data' do
        expect(StatsD).to receive(:increment).with('api.form1010cg.pdf_download')
        subject.record_pdf_download
      end
    end

    context 'logs' do
      it 'nothing' do
        expect(Rails.logger).not_to receive(:info)
        subject.record_pdf_download
      end
    end
  end

  describe '#log_mpi_search_result' do
    context 'requires' do
      it 'claim_guid:, form_subject:, result:' do
        expect { subject.log_mpi_search_result }.to raise_error(ArgumentError) do |e|
          expect(e.message).to eq('missing keywords: claim_guid, form_subject, result')
        end
      end
    end

    context 'increments' do
      it 'nothing' do
        expect(StatsD).not_to receive(:increment)
        subject.log_mpi_search_result(claim_guid: 'uuid-123', form_subject: 'veteran', result: :found)
      end
    end

    context 'logs' do
      it 'The search result with the form_subject titleized' do
        [
          {
            input: { claim_guid: 'uuid-123', form_subject: 'veteran', result: :found },
            expectation: '[Form 10-10CG] MPI Profile found for Veteran'
          },
          {
            input: { claim_guid: 'uuid-123', form_subject: 'veteran', result: :not_found },
            expectation: '[Form 10-10CG] MPI Profile NOT FOUND for Veteran'
          },
          {
            input: { claim_guid: 'uuid-123', form_subject: 'veteran', result: :skipped },
            expectation: '[Form 10-10CG] MPI Profile search was skipped for Veteran'
          },
          {
            input: { claim_guid: 'uuid-123', form_subject: 'primaryCaregiver', result: :found },
            expectation: '[Form 10-10CG] MPI Profile found for Primary Caregiver'
          },
          {
            input: { claim_guid: 'uuid-123', form_subject: 'primaryCaregiver', result: :not_found },
            expectation: '[Form 10-10CG] MPI Profile NOT FOUND for Primary Caregiver'
          },
          {
            input: { claim_guid: 'uuid-123', form_subject: 'primaryCaregiver', result: :skipped },
            expectation: '[Form 10-10CG] MPI Profile search was skipped for Primary Caregiver'
          },
          {
            input: { claim_guid: 'uuid-123', form_subject: 'secondaryCaregiverOne', result: :found },
            expectation: '[Form 10-10CG] MPI Profile found for Secondary Caregiver One'
          },
          {
            input: { claim_guid: 'uuid-123', form_subject: 'secondaryCaregiverOne', result: :not_found },
            expectation: '[Form 10-10CG] MPI Profile NOT FOUND for Secondary Caregiver One'
          },
          {
            input: { claim_guid: 'uuid-123', form_subject: 'secondaryCaregiverOne', result: :skipped },
            expectation: '[Form 10-10CG] MPI Profile search was skipped for Secondary Caregiver One'
          }
        ].each do |input:, expectation:|
          expect(Rails.logger).to receive(:info).with(expectation, claim_guid: input[:claim_guid])
          subject.log_mpi_search_result(input)
        end
      end
    end
  end

  describe '#record' do
    describe 'acts as proxy' do
      context 'for :submission_attempt' do
        it 'calls :record submission_attempt' do
          expect(subject).to receive(:record_submission_attempt)
          subject.record(:submission_attempt)
        end
      end

      context 'for :submission_success' do
        it 'calls :record submission_success' do
          context = {
            claim_guid: 'uuid-123',
            carma_case_id: 'CASE_123',
            metadata: {},
            attachments: {},
            attachments_job_id: '123abc'
          }

          expect(subject).to receive(:record_submission_success).with(context)
          subject.record(:submission_success, context)
        end
      end

      context 'for :submission_failure_client_data' do
        it 'calls :record submission_failure_client_data' do
          context = { claim_guid: 'uuid-123', errors: %w[error1 error2] }

          expect(subject).to receive(:record_submission_failure_client_data).with(context)
          subject.record(:submission_failure_client_data, context)
        end
      end

      context 'for :submission_failure_client_qualification' do
        it 'calls :record submission_failure_client_qualification' do
          context = { claim_guid: 'uuid-123' }

          expect(subject).to receive(:record_submission_failure_client_qualification).with(context)
          subject.record(:submission_failure_client_qualification, context)
        end
      end

      context 'for :pdf_download' do
        it 'calls :record pdf_download' do
          expect(subject).to receive(:record_pdf_download)
          subject.record(:pdf_download)
        end
      end
    end
  end
end
