# frozen_string_literal: true

require 'rails_helper'
require 'bpds/monitor'

RSpec.describe BPDS::Monitor do
  let(:monitor) { described_class.new }
  let(:saved_claim_id) { 123 }
  let(:bpds_uuid) { 'abc-123' }
  let(:error) { StandardError.new('Something went wrong') }

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
end
