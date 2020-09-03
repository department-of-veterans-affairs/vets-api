# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::V1::FHIRService do
  subject { HealthQuest::V1::FHIRService.new(resource_type: :Organization, user: user) }

  let(:user) { build(:user, :health_quest) }

  before { allow_any_instance_of(HealthQuest::UserService).to receive(:session).and_return('stubbed_token') }

  VCR.configure do |c|
    c.before_record do |i|
      i.response.body.force_encoding('UTF-8')
    end
  end

  context 'with an invalid resource type' do
    it 'raises an invalid field value exception' do
      expect { HealthQuest::V1::FHIRService.new(resource_type: :House, user: user) }.to raise_error(
        Common::Exceptions::InvalidFieldValue
      ) { |e| expect(e.errors.first.detail).to eq('"House" is not a valid value for "resource_type"') }
    end
  end

  describe '#read' do
    context 'when HealthQuest returns a 404' do
      it 'raises a backend exception with key HealthQuest_404' do
        VCR.use_cassette('health_quest/fhir/read_organization_404', match_requests_on: %i[method uri]) do
          expect { subject.read(353_000) }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) { |e| expect(e.key).to eq('HEALTH_QUEST_404') }
        end
      end
    end

    context 'with valid args' do
      let(:expected_body) do
        YAML.load_file(
          Rails.root.join(
            'spec', 'support', 'vcr_cassettes', 'health_quest', 'fhir', 'read_organization_200.yml'
          )
        )['http_interactions'].first.dig('response', 'body', 'string')
      end

      it 'returns the JSON response body from the VAMF response' do
        VCR.use_cassette('health_quest/fhir/read_organization_200', match_requests_on: %i[method uri]) do
          response = subject.read(353_830)
          expect(response.body).to eq(expected_body)
        end
      end
    end

    context 'when health_quest debugging is enabled' do
      it 'logs the request in curl format' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('HEALTH_QUEST_DEBUG').and_return('true')
        VCR.use_cassette('health_quest/fhir/read_organization_200', match_requests_on: %i[method uri]) do
          silence do
            expect_any_instance_of(::Logger).to receive(:warn).once
            subject.read(353_830)
          end
        end
      end
    end
  end

  describe '#search' do
    context 'when VAMF returns a 500' do
      xit 'raises a backend exception with key HealthQuest_502' do
        VCR.use_cassette('health_quest/fhir/search_organization_500', match_requests_on: %i[method uri]) do
          expect { subject.search({ 'identifier' => '353000' }) }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) { |e| expect(e.key).to eq('HealthQuest_502') }
        end
      end
    end

    context 'with valid args' do
      let(:expected_body) do
        YAML.load_file(
          Rails.root.join(
            'spec', 'support', 'vcr_cassettes', 'health_quest', 'fhir', 'search_organization_200.yml'
          )
        )['http_interactions'].first.dig('response', 'body', 'string')
      end

      xit 'returns the JSON response body from the VAMF response' do
        VCR.use_cassette('health_quest/fhir/search_organization_200', match_requests_on: %i[method uri]) do
          response = subject.search({ 'identifier' => '983,984' })
          expect(response.body).to eq(expected_body)
        end
      end
    end
  end
end
