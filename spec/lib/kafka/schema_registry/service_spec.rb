# frozen_string_literal: true

require 'rails_helper'
require 'kafka/schema_registry/service'

describe Kafka::SchemaRegistry::Service do
  let(:service) { described_class.new }
  let(:topic_name) { 'topic-1' }
  let(:version) { '1' }
  let(:topic_1_response) do
    { 'subject' => 'topic-1-value',
      'version' => 1,
      'id' => 5,
      'schema' => "{\"type\":\"record\",\"name\":\"SubmissionTrace\",\"namespace\":\"gov.va.submissiontrace.form.data\"\
,\"fields\":[{\"name\":\"priorId\",\"type\":[\"null\",\"string\"]},{\"name\":\"currentId\",\"type\":\"string\"},\
{\"name\":\"nextId\",\"type\":[\"null\",\"string\"]},{\"name\":\"icn\",\"type\":[\"null\",\"string\"]},\
{\"name\":\"vasiId\",\"type\":\"string\"},{\"name\":\"systemName\",\"type\":[{\"type\":\"enum\",\
\"name\":\"systemName\",\"symbols\":[\"Lighthouse\",\"CMP\",\"VBMS\",\"VA_gov\",\"VES\"]}]},\
{\"name\":\"submissionName\",\"type\":[{\"type\":\"enum\",\"name\":\"submissionName\",\"symbols\":[\"F1010EZ\"\
,\"F527EZ\"]}]},{\"name\":\"state\",\"type\":\"string\"},{\"name\":\"timestamp\",\"type\":\"string\"},\
{\"name\":\"additionalIds\",\"type\":[\"null\",{\"type\":\"array\",\"items\":\"string\"}]}]}"}
  end

  describe '#subject_versions' do
    it 'appends -value to topic name in request' do
      expected_response = [1]
      expect(service).to receive(:request)
        .with('/ves-event-bus-infra/schema-registry/subjects/topic-1-value/versions', { idempotent: true })
        .and_return(expected_response)

      response = service.subject_versions(topic_name)
      expect(response).to eq(expected_response)
    end
  end

  describe '#check' do
    it 'appends -value to topic name in request' do
      expected_response = JSON.parse(topic_1_response['schema'])
      expect(service).to receive(:request)
        .with('/ves-event-bus-infra/schema-registry/subjects/topic-1-value', any_args)
        .and_return(expected_response)

      response = service.check(topic_name, topic_1_response['schema'])
      expect(response).to eq(expected_response)
    end
  end

  describe '#compatible?' do
    it 'appends -value to topic name in request' do
      expected_response = { is_compatible: false, messages: 'schema may not be empty' }
      expect(service).to receive(:request)
        .with("/ves-event-bus-infra/schema-registry/compatibility/subjects/#{topic_name}-value/versions/latest",
              any_args)
        .and_return(expected_response)

      response = service.compatible?(topic_name, {})
      expect(response).to be(false)
    end
  end

  describe '#compatibility_issues' do
    it 'appends -value to topic name in request' do
      expected_response = { is_compatible: false, messages: 'schema may not be empty' }

      expect(service).to receive(:request)
        .with("/ves-event-bus-infra/schema-registry/compatibility/subjects/#{topic_name}-value/versions/latest",
              any_args)
        .and_return(expected_response)

      response = service.compatibility_issues(topic_name, {})
      expect(response).to eq('schema may not be empty')
    end
  end

  describe '#subject_config' do
    it 'appends -value to topic name in request' do
      expected_response = {
        compatibility: 'FULL'
      }
      expect(service).to receive(:request)
        .with("/ves-event-bus-infra/schema-registry/config/#{topic_name}-value", any_args)
        .and_return(expected_response)

      response = service.subject_config(topic_name)
      expect(response).to eq(expected_response)
    end
  end

  describe '#subject_version' do
    it 'appends -value to topic name in request' do
      expect(service).to receive(:request)
        .with("/ves-event-bus-infra/schema-registry/subjects/#{topic_name}-value/versions/latest", any_args)
        .and_call_original

      VCR.use_cassette('kafka/topics') do
        response = service.subject_version(topic_name)
        expect(response).to eq(topic_1_response)
      end
    end

    context 'when requesting latest version' do
      it 'returns schema information' do
        VCR.use_cassette('kafka/topics') do
          response = service.subject_version(topic_name)
          expect(response).to eq(topic_1_response)
        end
      end
    end

    context 'when requesting specific version' do
      it 'returns schema information for that version' do
        VCR.use_cassette('kafka/topics') do
          response = service.subject_version(topic_name, version)
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
