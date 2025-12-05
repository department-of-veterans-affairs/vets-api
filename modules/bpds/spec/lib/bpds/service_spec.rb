# frozen_string_literal: true

require 'rails_helper'
require 'bpds/service'
require 'burials/bpds/formatter'

RSpec.describe BPDS::Service do
  let(:service) { described_class.new }
  let(:formatted_claim_form) { { 'key' => 'value' } }
  let(:form_id) { '21-526EZ' }
  let(:participant_id) { '123456' }
  let(:file_number) { '123456789' }
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
    context 'when participant_id is provided' do
      it 'returns the response body' do
        expect(service).to receive(:perform).with(:post, '', anything, anything).and_return(response)

        result = service.submit_json(formatted_claim_form, form_id, participant_id, nil)
        expect(result).to eq('response body')
      end
    end

    context 'when file_number is provided' do
      it 'returns the response body' do
        expect(service).to receive(:perform).with(:post, '', anything, anything).and_return(response)

        result = service.submit_json(formatted_claim_form, form_id, nil, file_number)
        expect(result).to eq('response body')
      end
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
    context 'when a participant id is present' do
      it 'returns the default payload with the participant id' do
        expected_payload = {
          'bpd' => {
            'sensitivityLevel' => 0,
            'payloadNamespace' => "urn:vets_api:#{form_id}:#{Settings.bpds.schema_version}",
            'participantId' => participant_id,
            'fileNumber' => nil,
            'payload' => formatted_claim_form
          }
        }
        expect(service.send(:default_payload, formatted_claim_form, form_id, participant_id,
                            nil)).to eq(expected_payload)
      end
    end

    context 'when a file number is present' do
      it 'returns the default payload with the file number' do
        expected_payload = {
          'bpd' => {
            'sensitivityLevel' => 0,
            'payloadNamespace' => "urn:vets_api:#{form_id}:#{Settings.bpds.schema_version}",
            'participantId' => nil,
            'fileNumber' => file_number,
            'payload' => formatted_claim_form
          }
        }
        expect(service.send(:default_payload, formatted_claim_form, form_id, nil, file_number)).to eq(expected_payload)
      end
    end

    context 'when formatted data is provided' do
      let(:formatted_result) { { 'veteranName' => { 'first' => 'John' } } }
      let(:burial_form_id) { '21P-530EZ' }

      it 'uses the formatted payload in the default_payload' do
        expected_payload = {
          'bpd' => {
            'sensitivityLevel' => 0,
            'payloadNamespace' => "urn:vets_api:#{burial_form_id}:#{Settings.bpds.schema_version}",
            'participantId' => participant_id,
            'fileNumber' => nil,
            'payload' => formatted_result
          }
        }
        expect(service.send(:default_payload, formatted_result, burial_form_id, participant_id,
                            nil)).to eq(expected_payload)
      end
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
