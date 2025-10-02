# frozen_string_literal: true

require 'rails_helper'
require 'bpds/monitor'

RSpec.describe BPDS::Monitor do
  let(:monitor) { described_class.new }
  let(:saved_claim_id) { 123 }
  let(:bpds_uuid) { 'abc-123' }
  let(:error) { StandardError.new('Something went wrong') }
  let(:user_type) { 'loa3' }
  let(:service_name) { 'mpi' }
  let(:is_pid_present) { true }
  let(:is_file_number_present) { false }

  describe '#track_submit_begun' do
    it 'tracks the submit begun event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "BPDS::Service submit begun for saved_claim ##{saved_claim_id}",
        'api.bpds_service.submit_json.begun',
        call_location: instance_of(Thread::Backtrace::Location),
        saved_claim_id:
      )
      monitor.track_submit_begun(saved_claim_id)
    end
  end

  describe '#track_submit_success' do
    it 'tracks the submit success event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "BPDS::Service submit succeeded for saved_claim ##{saved_claim_id}",
        'api.bpds_service.submit_json.success',
        call_location: instance_of(Thread::Backtrace::Location),
        saved_claim_id:
      )
      monitor.track_submit_success(saved_claim_id)
    end
  end

  describe '#track_submit_failure' do
    it 'tracks the submit failure event' do
      expect(monitor).to receive(:track_request).with(
        'error',
        "BPDS::Service submit failed for saved_claim ##{saved_claim_id}",
        'api.bpds_service.submit_json.failure',
        call_location: instance_of(Thread::Backtrace::Location),
        saved_claim_id:,
        errors: error.message
      )
      monitor.track_submit_failure(saved_claim_id, error)
    end
  end

  describe '#track_get_json_begun' do
    it 'tracks the get_json begun event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "BPDS::Service get_json begun for bpds_uuid ##{bpds_uuid}",
        'api.bpds_service.get_json_by_bpds_uuid.begun',
        call_location: instance_of(Thread::Backtrace::Location),
        bpds_uuid:
      )
      monitor.track_get_json_begun(bpds_uuid)
    end
  end

  describe '#track_get_json_success' do
    it 'tracks the get_json success event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "BPDS::Service get_json succeeded for bpds_uuid ##{bpds_uuid}",
        'api.bpds_service.get_json_by_bpds_uuid.success',
        call_location: instance_of(Thread::Backtrace::Location),
        bpds_uuid:
      )
      monitor.track_get_json_success(bpds_uuid)
    end
  end

  describe '#track_get_json_failure' do
    it 'tracks the get_json failure event' do
      expect(monitor).to receive(:track_request).with(
        'error',
        "BPDS::Service get_json failed for bpds_uuid ##{bpds_uuid}",
        'api.bpds_service.get_json_by_bpds_uuid.failure',
        call_location: instance_of(Thread::Backtrace::Location),
        bpds_uuid:,
        errors: error.message
      )
      monitor.track_get_json_failure(bpds_uuid, error)
    end
  end

  describe '#track_get_user_identifier' do
    it 'tracks the get_user_identifier lookup event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "Pensions::V0::ClaimsController: #{user_type} user identifier lookup for BPDS",
        'api.bpds_service.get_participant_id',
        call_location: instance_of(Thread::Backtrace::Location),
        tags: ["user_type:#{user_type}"]
      )
      monitor.track_get_user_identifier(user_type)
    end
  end

  describe '#track_get_user_identifier_result' do
    it 'tracks the get_user_identifier result event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "Pensions::V0::ClaimsController: mpi service participant_id lookup result: #{is_pid_present}",
        'api.bpds_service.get_participant_id.mpi.result',
        call_location: instance_of(Thread::Backtrace::Location),
        service_name:,
        tags: ["pid_present:#{is_pid_present}"]
      )
      monitor.track_get_user_identifier_result(service_name, is_pid_present)
    end
  end

  describe '#track_get_user_identifier_result_file_number' do
    it 'tracks the get_user_identifier file number result event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "Pensions::V0::ClaimsController: BGS service file_number lookup result: #{is_file_number_present}",
        'api.bpds_service.get_file_number.bgs.result',
        call_location: instance_of(Thread::Backtrace::Location),
        tags: ["file_number_present:#{is_file_number_present}"]
      )
      monitor.track_get_user_identifier_file_number_result(is_file_number_present)
    end
  end

  describe '#track_skip_bpds_job' do
    it 'tracks the skip_bpds_job event' do
      expect(monitor).to receive(:track_request).with(
        'info',
        "Pensions::V0::ClaimsController: No user identifier found, skipping BPDS job for saved_claim #{saved_claim_id}",
        'api.bpds_service.job_skipped_missing_identifier',
        call_location: instance_of(Thread::Backtrace::Location),
        saved_claim_id:
      )
      monitor.track_skip_bpds_job(saved_claim_id)
    end
  end
end
