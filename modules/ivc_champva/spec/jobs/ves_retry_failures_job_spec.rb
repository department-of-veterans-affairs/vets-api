# frozen_string_literal: true

require 'rails_helper'
require 'ves_api/client'

RSpec.describe IvcChampva::VesRetryFailuresJob, type: :job do
  let(:job) { described_class.new }
  let(:ves_client) { instance_double(IvcChampva::VesApi::Client) }
  let(:success_response) { double('response', status: 200, body: 'success') }
  let(:error_response) { double('response', status: 500, body: 'server error') }
  let(:legacy_request_data) { { data: 'test_data', transaction_uuid: 'tx-old' }.to_json }
  let(:request_json_data) { { 'form_number' => '10-10D', 'applicants' => [] }.to_json }

  # Use instance_double instead of real database objects
  let(:recent_record) do
    instance_double(IvcChampvaForm,
                    form_uuid: 'form-123',
                    ves_status: 'failed',
                    created_at: 2.hours.ago)
  end

  let(:old_record) do
    instance_double(IvcChampvaForm,
                    form_uuid: 'form-456',
                    ves_status: 'failed',
                    created_at: 5.hours.ago)
  end

  let(:mock_ves_request) do
    instance_double(IvcChampva::VesRequest,
                    transaction_uuid: nil,
                    'transaction_uuid=' => nil,
                    subforms?: false)
  end

  before do
    ivc_forms = double('ivc_forms')
    sidekiq = double('sidekiq')
    job_settings = double('job_settings')

    allow(Settings).to receive(:ivc_forms).and_return(ivc_forms)
    allow(ivc_forms).to receive(:sidekiq).and_return(sidekiq)
    allow(job_settings).to receive(:enabled).and_return(true)

    allow(IvcChampva::VesApi::Client).to receive(:new).and_return(ves_client)
    allow(ves_client).to receive(:submit_1010d).and_return(success_response)
    allow(StatsD).to receive(:increment)
    allow(StatsD).to receive(:gauge)
    allow(SecureRandom).to receive(:uuid).and_return('tx-new')

    # Setup the records to allow updating and reloading
    allow(recent_record).to receive_messages(update: true, reload: recent_record)
    allow(old_record).to receive_messages(update: true, reload: old_record)

    # Default: records have legacy ves_request_data but no request_json
    allow(recent_record).to receive_messages(ves_request_data: legacy_request_data, request_json: nil)
    allow(old_record).to receive_messages(ves_request_data: legacy_request_data, request_json: nil)
  end

  describe '#perform' do
    context 'when setting is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_ves_retry_failures_job).and_return(false)
      end

      it 'returns early and does not process any records' do
        job.perform
        expect(IvcChampva::VesApi::Client).not_to have_received(:new)
      end
    end

    context 'when setting is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:champva_ves_retry_failures_job).and_return(true)
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

      it 'skips records with neither request_json nor ves_request_data' do
        record_without_data = instance_double(IvcChampvaForm,
                                              form_uuid: 'form-no-data',
                                              ves_status: 'failed',
                                              created_at: 2.hours.ago,
                                              request_json: nil,
                                              ves_request_data: nil)
        allow(record_without_data).to receive_messages(update: true)

        query_relation = double('ActiveRecord::Relation')
        allow(IvcChampvaForm).to receive(:where).with(no_args).and_return(query_relation)
        allow(query_relation).to receive(:not).with(ves_status: [nil, 'ok']).and_return([record_without_data])

        expect(Rails.logger).to receive(:warn).with(/no request_json or ves_request_data available/)

        job.perform

        expect(ves_client).not_to have_received(:submit_1010d)
      end
    end
  end

  describe '#can_retry?' do
    it 'returns true when request_json is present' do
      allow(recent_record).to receive(:request_json).and_return(request_json_data)
      expect(job.can_retry?(recent_record)).to be true
    end

    it 'returns true when only ves_request_data is present (legacy fallback)' do
      allow(recent_record).to receive_messages(request_json: nil, ves_request_data: legacy_request_data)
      expect(job.can_retry?(recent_record)).to be true
    end

    it 'returns false and logs warning when neither is present' do
      allow(recent_record).to receive_messages(request_json: nil, ves_request_data: nil)

      expect(Rails.logger).to receive(:warn).with(/no request_json or ves_request_data available/)
      expect(job.can_retry?(recent_record)).to be false
    end
  end

  describe '#resubmit_ves_request' do
    context 'with request_json (new approach)' do
      before do
        allow(recent_record).to receive(:request_json).and_return(request_json_data)
        allow(IvcChampva::VesDataFormatter).to receive(:format_for_request).and_return(mock_ves_request)
        allow(mock_ves_request).to receive(:transaction_uuid=)
      end

      it 'rebuilds VES request using VesDataFormatter and submits' do
        expect(IvcChampva::VesDataFormatter).to receive(:format_for_request)
        expect(ves_client).to receive(:submit_1010d).and_return(success_response)

        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(ves_status: 'ok')
      end
    end

    context 'with request_json for 10-10D-EXTENDED' do
      let(:extended_request_json) { { 'form_number' => '10-10D-EXTENDED', 'applicants' => [] }.to_json }
      let(:mock_ves_request_with_subforms) do
        instance_double(IvcChampva::VesRequest,
                        transaction_uuid: nil,
                        'transaction_uuid=' => nil,
                        subforms?: true,
                        subforms: [{ form_type: 'vha_10_7959c', request: mock_ohi_request }])
      end
      let(:mock_ohi_request) do
        instance_double(IvcChampva::VesOhiRequest,
                        transaction_uuid: nil,
                        'transaction_uuid=' => nil)
      end

      before do
        allow(recent_record).to receive(:request_json).and_return(extended_request_json)
        allow(IvcChampva::VesDataFormatter).to receive(:format_for_extended_request)
          .and_return(mock_ves_request_with_subforms)
        allow(mock_ves_request_with_subforms).to receive(:transaction_uuid=)
        allow(mock_ohi_request).to receive(:transaction_uuid=)
        allow(ves_client).to receive(:submit_7959c).and_return(success_response)
      end

      it 'uses format_for_extended_request and submits subforms' do
        expect(IvcChampva::VesDataFormatter).to receive(:format_for_extended_request)
        expect(ves_client).to receive(:submit_1010d).and_return(success_response)
        expect(ves_client).to receive(:submit_7959c).and_return(success_response)

        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(ves_status: 'ok')
      end
    end

    context 'with legacy ves_request_data (fallback)' do
      before do
        allow(recent_record).to receive_messages(request_json: nil, ves_request_data: legacy_request_data)
      end

      it 'parses ves_request_data and submits directly' do
        expect(ves_client).to receive(:submit_1010d) do |uuid, _user, request_data|
          expect(request_data['transaction_uuid']).to eq(uuid)
          success_response
        end

        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(ves_status: 'ok')
      end
    end

    context 'with an error response' do
      before do
        allow(recent_record).to receive(:request_json).and_return(nil)
        allow(ves_client).to receive(:submit_1010d).and_return(error_response)
      end

      it 'updates the record status with the error body' do
        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(
          ves_status: 'server error'
        )
      end
    end

    context 'with invalid JSON data in ves_request_data' do
      let(:invalid_record) do
        instance_double(IvcChampvaForm,
                        form_uuid: 'form-789',
                        ves_status: 'failed',
                        created_at: 2.hours.ago,
                        request_json: nil,
                        ves_request_data: 'invalid json')
      end

      before do
        allow(invalid_record).to receive_messages(update: true, reload: invalid_record)
      end

      it 'raises JSON parse error' do
        expect { job.resubmit_ves_request(invalid_record) }.to raise_error(JSON::ParserError)
      end
    end

    context 'with unsupported form_number in request_json' do
      let(:unsupported_form_json) { { 'form_number' => '10-7959A', 'applicants' => [] }.to_json }

      before do
        allow(recent_record).to receive(:request_json).and_return(unsupported_form_json)
      end

      it 'logs warning and does not submit' do
        expect(Rails.logger).to receive(:warn).with(/Unsupported form_number for VES retry/)
        expect(Rails.logger).to receive(:warn).with(/No VES requests built/)
        expect(ves_client).not_to receive(:submit_1010d)

        job.resubmit_ves_request(recent_record)
      end
    end

    context 'with request_json for standalone 10-7959C (OHI)' do
      let(:ohi_request_json) { { 'form_number' => '10-7959C', 'applicants' => [] }.to_json }
      let(:mock_ohi_request1) do
        instance_double(IvcChampva::VesOhiRequest,
                        transaction_uuid: nil,
                        'transaction_uuid=' => nil)
      end
      let(:mock_ohi_request2) do
        instance_double(IvcChampva::VesOhiRequest,
                        transaction_uuid: nil,
                        'transaction_uuid=' => nil)
      end

      before do
        allow(recent_record).to receive(:request_json).and_return(ohi_request_json)
        allow(mock_ohi_request1).to receive(:respond_to?).with(:subforms?).and_return(false)
        allow(mock_ohi_request2).to receive(:respond_to?).with(:subforms?).and_return(false)
      end

      it 'submits all OHI requests when multiple beneficiaries exist' do
        allow(IvcChampva::VesDataFormatter).to receive(:format_for_ohi_request)
          .and_return([mock_ohi_request1, mock_ohi_request2])

        expect(ves_client).to receive(:submit_7959c).twice.and_return(success_response)

        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(ves_status: 'ok')
      end

      it 'marks as partial_failure when one request fails' do
        allow(IvcChampva::VesDataFormatter).to receive(:format_for_ohi_request)
          .and_return([mock_ohi_request1, mock_ohi_request2])

        expect(ves_client).to receive(:submit_7959c).and_return(success_response).ordered
        expect(ves_client).to receive(:submit_7959c).and_return(error_response).ordered

        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(ves_status: 'partial_failure')
      end

      it 'handles single OHI request' do
        allow(IvcChampva::VesDataFormatter).to receive(:format_for_ohi_request)
          .and_return([mock_ohi_request1])

        expect(ves_client).to receive(:submit_7959c).once.and_return(success_response)

        job.resubmit_ves_request(recent_record)

        expect(recent_record).to have_received(:update).with(ves_status: 'ok')
      end
    end
  end
end
