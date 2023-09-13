# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Auditor do
  describe '::metrics' do
    it 'provides StatsD metric values' do
      expect(
        described_class.metrics.submission.attempt
      ).to eq('api.form1010cg.submission.attempt')
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

  describe '#record_caregivers' do
    subject do
      described_class.new.record_caregivers(claim)
    end

    let(:claim) { build(:caregivers_assistance_claim) }

    it 'increments primary_no_secondary' do
      allow(claim).to receive(:secondary_caregiver_one_data).and_return(nil)
      expect { subject }.to trigger_statsd_increment('api.form1010cg.submission.caregivers.primary_no_secondary')
    end

    it 'increments primary_one_secondary' do
      expect { subject }.to trigger_statsd_increment('api.form1010cg.submission.caregivers.primary_one_secondary')
    end

    it 'increments primary_two_secondary' do
      allow(claim).to receive(:secondary_caregiver_two_data).and_return(claim.secondary_caregiver_one_data)
      expect { subject }.to trigger_statsd_increment('api.form1010cg.submission.caregivers.primary_two_secondary')
    end

    context 'no primary' do
      before do
        allow(claim).to receive(:primary_caregiver_data).and_return(nil)
      end

      it 'increments no_primary_one_secondary' do
        expect { subject }.to trigger_statsd_increment('api.form1010cg.submission.caregivers.no_primary_one_secondary')
      end

      it 'increments no_primary_two_secondary' do
        allow(claim).to receive(:secondary_caregiver_two_data).and_return(claim.secondary_caregiver_one_data)
        expect { subject }.to trigger_statsd_increment('api.form1010cg.submission.caregivers.no_primary_two_secondary')
      end
    end
  end

  describe '#record_submission_attempt' do
    context 'increments' do
      it 'api.form1010cg.submission.attempt' do
        expect { subject.record_submission_attempt }
          .to trigger_statsd_increment('api.form1010cg.submission.attempt')
      end
    end

    context 'logs' do
      it 'nothing' do
        expect(Rails.logger).not_to receive(:info)
        subject.record_submission_attempt
      end
    end
  end

  describe '#record_submission_failure_client_data' do
    context 'requires' do
      it 'errors:' do
        expect { subject.record_submission_failure_client_data }.to raise_error(ArgumentError) do |e|
          expect(e.message).to eq('missing keyword: :errors')
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

        expect { subject.record_submission_failure_client_data(**expected_context) }
          .to trigger_statsd_increment('api.form1010cg.submission.failure.client.data')
      end
    end

    context 'logs' do
      it '[Form 10-10CG] Submission Failed: invalid data provided by client' do
        expected_message = '[Form 10-10CG] Submission Failed: invalid data provided by client'
        expected_context = { errors: %w[error1 error2], claim_guid: 'uuid-123' }

        expect(Rails.logger).to receive(:info).with(expected_message, expected_context)

        subject.record_submission_failure_client_data(**expected_context)
      end
    end
  end

  describe '#record_submission_failure_client_qualification' do
    context 'requires' do
      it 'claim_guid:, veteran_name:' do
        expect { subject.record_submission_failure_client_qualification }.to raise_error(ArgumentError) do |e|
          expect(e.message).to eq('missing keyword: :claim_guid')
        end
      end
    end

    context 'increments' do
      it 'api.form1010cg.submission.failure.client.data' do
        expected_context = { claim_guid: 'uuid-123' }

        expect { subject.record_submission_failure_client_qualification(**expected_context) }
          .to trigger_statsd_increment('api.form1010cg.submission.failure.client.qualification')
      end
    end

    context 'logs' do
      it '[Form 10-10CG] Submission Failed: qualifications not met' do
        expected_message = '[Form 10-10CG] Submission Failed: qualifications not met'
        expected_context = { claim_guid: 'uuid-123' }

        expect(Rails.logger).to receive(:info).with(expected_message, expected_context)

        subject.record_submission_failure_client_qualification(**expected_context)
      end
    end
  end

  describe '#record_pdf_download' do
    context 'increments' do
      it 'api.form1010cg.submission.failure.client.data' do
        expect { subject.record_pdf_download }
          .to trigger_statsd_increment('api.form1010cg.pdf_download')
      end
    end

    context 'logs' do
      it 'nothing' do
        expect(Rails.logger).not_to receive(:info)
        subject.record_pdf_download
      end
    end
  end

  describe '#record_attachments_delivered' do
    let(:subject) do
      described_class.new(Sidekiq.logger)
    end

    context 'logs' do
      it '[Form 10-10CG] Attachments Delivered' do
        expected_message = '[Form 10-10CG] Attachments Delivered'
        expected_context = { claim_guid: 'uuid-123', carma_case_id: 'CASE_123', attachments: :ATTACHMENTS_HASH }

        expect(Sidekiq.logger).to receive(:info).with(expected_message, expected_context)
        subject.record_attachments_delivered(**expected_context)
      end
    end
  end

  describe '#log_mpi_search_result' do
    context 'requires' do
      it 'claim_guid:, form_subject:, result:' do
        expect { subject.log_mpi_search_result }.to raise_error(ArgumentError) do |e|
          expect(e.message).to eq('missing keywords: :claim_guid, :form_subject, :result')
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
        ].each do |options|
          expect(Rails.logger).to receive(:info).with(options[:expectation], claim_guid: options[:input][:claim_guid])
          subject.log_mpi_search_result(**options[:input])
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

      context 'for :submission_failure_client_data' do
        it 'calls :record_submission_failure_client_data' do
          context = { claim_guid: 'uuid-123', errors: %w[error1 error2] }

          expect(subject).to receive(:record_submission_failure_client_data).with(context)
          subject.record(:submission_failure_client_data, **context)
        end
      end

      context 'for :submission_failure_client_qualification' do
        it 'calls :record_submission_failure_client_qualification' do
          context = { claim_guid: 'uuid-123' }

          expect(subject).to receive(:record_submission_failure_client_qualification).with(context)
          subject.record(:submission_failure_client_qualification, **context)
        end
      end

      context 'for :pdf_download' do
        it 'calls :record_pdf_download' do
          expect(subject).to receive(:record_pdf_download)
          subject.record(:pdf_download)
        end
      end

      context 'for :attachments_delivered' do
        it 'calls :record_attachments_delivered' do
          context = {
            claim_guid: 'uuid-123',
            carma_case_id: 'CASE_123',
            attachments: {}
          }

          expect(subject).to receive(:record_attachments_delivered).with(context)
          subject.record(:attachments_delivered, **context)
        end
      end
    end
  end
end
