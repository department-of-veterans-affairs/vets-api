# frozen_string_literal: true

require 'rails_helper'
require 'bpds/service'

RSpec.describe BPDS::Service do
  let(:service) { described_class.new }
  let(:claim) { double('SavedClaim', id: 1, form_id: '21-526EZ', parsed_form: { 'key' => 'value' }) }
  let(:participant_id) { '123456' }
  let(:bpds_uuid) { 'some-uuid' }
  let(:response) { double('response', body: 'response body') }

  before do
    allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(true)
    allow(service).to receive(:perform).and_return(response)
  end

  describe '#submit_json' do
    context 'when claim is nil' do
      it 'returns nil' do
        expect(service.submit_json(nil)).to be_nil
      end
    end

    context 'when claim is present' do
      it 'tracks the submission process and returns the response body' do
        expect(service.monitor).to receive(:track_submit_begun).with(claim.id)
        expect(service.monitor).to receive(:track_submit_success).with(claim.id)
        expect(service).to receive(:perform).with(:post, '', anything, anything).and_return(response)

        result = service.submit_json(claim, participant_id)
        expect(result).to eq('response body')
      end

      it 'tracks the failure and raises an error' do
        allow(service).to receive(:perform).and_raise(StandardError.new('error'))
        expect(service.monitor).to receive(:track_submit_failure).with(claim.id, instance_of(StandardError))

        expect { service.submit_json(claim, participant_id) }.to raise_error(StandardError, 'error')
      end
    end
  end

  describe '#get_json_by_bpds_uuid' do
    it 'tracks the retrieval process and returns the response body' do
      expect(service.monitor).to receive(:track_get_json_begun).with(bpds_uuid)
      expect(service.monitor).to receive(:track_get_json_success).with(bpds_uuid)
      expect(service).to receive(:perform).with(:get, bpds_uuid, nil, anything).and_return(response)

      result = service.get_json_by_bpds_uuid(bpds_uuid)
      expect(result).to eq('response body')
    end

    it 'tracks the failure and raises an error' do
      allow(service).to receive(:perform).and_raise(StandardError.new('error'))
      expect(service.monitor).to receive(:track_get_json_failure).with(bpds_uuid, instance_of(StandardError))

      expect { service.get_json_by_bpds_uuid(bpds_uuid) }.to raise_error(StandardError, 'error')
    end
  end

  describe '#default_payload' do
    it 'returns the default payload for a given claim' do
      expected_payload = {
        'bpd' => {
          'sensitivityLevel' => 0,
          'payloadNamespace' => "urn:vets_api:#{claim.form_id}:#{Settings.bpds.schema_version}",
          'payload' => claim.parsed_form
        }
      }
      expect(service.send(:default_payload, claim)).to eq(expected_payload)
    end

    it 'returns nil if claim is nil' do
      expect(service.send(:default_payload, nil)).to be_nil
    end
  end

  describe '#bpds_namespace' do
    it 'returns the BPDS namespace string based on the form ID and schema version' do
      form_id = '21-526EZ'
      expected_namespace = "urn:vets_api:#{form_id}:#{Settings.bpds.schema_version}"
      expect(service.send(:bpds_namespace, form_id)).to eq(expected_namespace)
    end
  end
end
