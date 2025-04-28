# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe IvcChampva::VesRetryFailuresJob, type: :job do
  let(:job) { described_class.new }
  let(:ves_client) { instance_double(IvcChampva::VesApi::Client) }
  let(:success_response) { double('response', status: 200, body: 'success') }
  let(:error_response) { double('response', status: 500, body: 'server error') }

  # Use instance_double instead of real database objects
  let(:recent_record) do
    instance_double(IvcChampvaForm,
                    form_uuid: 'form-123',
                    ves_status: 'failed',
                    created_at: 2.hours.ago,
                    ves_request_data: { 'data' => 'test_data', 'transaction_uuid' => 'tx-old' })
  end

  let(:old_record) do
    instance_double(IvcChampvaForm,
                    form_uuid: 'form-456',
                    ves_status: 'failed',
                    created_at: 5.hours.ago,
                    ves_request_data: { 'data' => 'test_data', 'transaction_uuid' => 'tx-old' })
  end

  before do
    ivc_forms = double('ivc_forms')
    sidekiq = double('sidekiq')
    job_settings = double('job_settings')

    allow(Settings).to receive(:ivc_forms).and_return(ivc_forms)
    allow(ivc_forms).to receive(:sidekiq).and_return(sidekiq)
    allow(sidekiq).to receive(:ves_retry_failures_job).and_return(job_settings)
    allow(job_settings).to receive(:enabled).and_return(true)

    allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
    allow(ves_client).to receive(:submit_1010d).and_return(success_response)
    allow(StatsD).to receive(:increment)
    allow(StatsD).to receive(:gauge)
    allow(SecureRandom).to receive(:uuid).and_return('tx-new')

    # Setup the records to allow updating and reloading
    allow(recent_record).to receive_messages(update: true, reload: recent_record)
    allow(old_record).to receive_messages(update: true, reload: old_record)

    # Allow records to have their ves_request_data modified
    recent_ves_data = recent_record.ves_request_data
    old_ves_data = old_record.ves_request_data
    allow(recent_record).to receive(:ves_request_data).and_return(recent_ves_data)
    allow(old_record).to receive(:ves_request_data).and_return(old_ves_data)
  end

  describe '#perform' do
    context 'when setting is disabled' do
      before do
        allow(Settings.ivc_forms.sidekiq.ves_retry_failures_job).to receive(:enabled).and_return(false)
      end

      it 'returns early and does not process any records' do
        job.perform
        expect(IvcChampva::VesApi::Client).not_to have_received(:new)
      end
    end

    context 'when setting is enabled' do
      before do
        query_relation = double('ActiveRecord::Relation')
        allow(IvcChampvaForm).to receive(:where).with(no_args).and_return(query_relation)
        allow(query_relation).to receive(:not).with(ves_status: [nil, 'ok']).and_return([recent_record, old_record])
      end

      it 'processes only records newer than 5 hours' do
        job.perform

        expect(ves_client).to have_received(:submit_1010d).once

        expect(recent_record).to have_received(:update).with(
          ves_status: 'ok'
        )

        expect(ves_client).to have_received(:submit_1010d) do |transaction_uuid, user, request|
          expect(transaction_uuid).to eq('tx-new')
          expect(request['transaction_uuid']).to eq('tx-new')
          expect(user).to eq('fake-user')
        end
      end

      it 'increments StatsD counter for old records with form_uuid tag' do
        job.perform
        expect(StatsD).to have_received(:increment).with(
          'ivc_champva.ves_submission_failures',
          tags: ['id:form-456']
        )
      end

      it 'sends gauge metric with count of failed submissions' do
        job.perform
        expect(StatsD).to have_received(:gauge).with('ivc_champva.ves_submission_failures.count', 2)
      end

      it 'properly queries for non-ok records excluding nil status' do
        query_relation = double('ActiveRecord::Relation')

        expect(IvcChampvaForm).to receive(:where).with(no_args).and_return(query_relation)
        expect(query_relation).to receive(:not).with(ves_status: [nil, 'ok']).and_return([recent_record, old_record])

        job.perform
      end

      it 'does not include records with nil ves_status' do
        query_relation = double('ActiveRecord::Relation')
        filtered_records = [recent_record, old_record]

        # Simulate the where.not filtering by returning only non-nil records
        allow(IvcChampvaForm).to receive(:where).with(no_args).and_return(query_relation)
        allow(query_relation).to receive(:not).with(ves_status: [nil, 'ok']).and_return(filtered_records)

        job.perform

        # Verify we processed only the non-nil records
        expect(StatsD).to have_received(:gauge).with('ivc_champva.ves_submission_failures.count', 2)
      end
    end
  end

  describe '#resubmit_ves_request' do
    context 'with a successful response' do
      it 'updates the record status to ok' do
        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(
          ves_status: 'ok'
        )

        expect(recent_record.ves_request_data['transaction_uuid']).to eq('tx-new')
      end
    end

    context 'with an error response' do
      before do
        allow(ves_client).to receive(:submit_1010d).and_return(error_response)
      end

      it 'updates the record status with the error body' do
        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(
          ves_status: 'server error'
        )

        expect(recent_record.ves_request_data['transaction_uuid']).to eq('tx-new')
      end
    end
  end
end
