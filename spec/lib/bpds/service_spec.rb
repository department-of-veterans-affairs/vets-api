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

  describe '#initialize' do
    it 'raises an error if bpds service flipper is disabled' do
      allow(Flipper).to receive(:enabled?).with(:bpds_service_enabled).and_return(false)
      expect { described_class.new }.to raise_error Common::Exceptions::Forbidden
    end
  end

  describe '#submit_json' do
    it 'raises an error if claim is nil' do
      expect { service.submit_json(nil) }.to raise_error NoMethodError
    end

    it 'returns the response body when claim is present' do
      expect(service).to receive(:perform).with(:post, '', anything, anything).and_return(response)

      result = service.submit_json(claim, participant_id)
      expect(result).to eq('response body')
    end
  end

  describe '#get_json_by_bpds_uuid' do
    it 'returns the response body' do
      expect(service).to receive(:perform).with(:get, 'testUUID', anything, anything).and_return(response)

      result = service.get_json_by_bpds_uuid('testUUID')
      expect(result).to eq('response body')
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
  end

  describe '#bpds_namespace' do
    it 'returns the BPDS namespace string based on the form ID and schema version' do
      form_id = '99-2342TEST'
      expected_namespace = "urn:vets_api:#{form_id}:#{Settings.bpds.schema_version}"
      expect(service.send(:bpds_namespace, form_id)).to eq(expected_namespace)
    end
  end
end
