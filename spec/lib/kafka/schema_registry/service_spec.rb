# frozen_string_literal: true

require 'rails_helper'
require 'kafka/schema_registry/service'

describe Kafka::SchemaRegistry::Service do
  let(:service) { described_class.new }
  let(:subject_name) { 'topic-1' }
  let(:version) { '1' }
  let(:topic_1_response) do
    { 'subject' => 'topic-1-value',
      'version' => 1,
      'id' => 5,
      'schema' => "{\"type\":\"record\",\"name\":\"TestRecord\",\"namespace\":\"gov.va.eventbus.test.data\"\
,\"fields\":[{\"name\":\"data\",\"type\":{\"type\":\"map\",\"values\":\"string\"},\"default\":{}}]}" }
  end

  describe '#subject_version' do
    context 'when requesting latest version' do
      it 'returns schema information' do
        VCR.use_cassette('kafka/topics') do
          response = service.subject_version(subject_name)
          expect(response).to eq(topic_1_response)
        end
      end
    end

    context 'when requesting specific version' do
      it 'returns schema information for that version' do
        VCR.use_cassette('kafka/topics') do
          response = service.subject_version(subject_name, version)
          expect(response).to eq(topic_1_response)
        end
      end
    end

    context 'when subject does not exist' do
      let(:nonexistent_subject) { 'topic-999' }

      it 'raises a ResourceNotFound error' do
        VCR.use_cassette('kafka/topics404') do
          expect { service.subject_version(nonexistent_subject) }
            .to raise_error(Faraday::ResourceNotFound)
        end
      end
    end
  end
end
