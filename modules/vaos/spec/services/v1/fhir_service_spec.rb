# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V1::FHIRService do
  subject { VAOS::V1::FHIRService.new(resource_type: :Organization, user:) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  VCR.configure do |c|
    c.before_record do |i|
      i.response.body.force_encoding('UTF-8')
    end
  end

  context 'with an invalid resource type' do
    it 'raises an invalid field value exception' do
      expect { VAOS::V1::FHIRService.new(resource_type: :House, user:) }.to raise_error(
        Common::Exceptions::InvalidFieldValue
      ) { |e| expect(e.errors.first.detail).to eq('"House" is not a valid value for "resource_type"') }
    end
  end

  describe '#read' do
    context 'when VAMF returns a 404' do
      it 'raises a backend exception with key VAOS_404' do
        VCR.use_cassette('vaos/fhir/read_organization_404', match_requests_on: %i[method path query]) do
          expect { subject.read(353_000) }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) { |e| expect(e.key).to eq('VAOS_404') }
        end
      end
    end

    context 'with valid args' do
      let(:expected_body) do
        YAML.load_file(
          Rails.root.join(
            'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'read_organization_200.yml'
          )
        )['http_interactions'].first.dig('response', 'body', 'string')
      end

      it 'returns the JSON response body from the VAMF response' do
        VCR.use_cassette('vaos/fhir/read_organization_200', match_requests_on: %i[method path query]) do
          response = subject.read(353_830)
          expect(response.body).to eq(expected_body)
        end
      end
    end

    context 'when vaos debugging is enabled' do
      it 'logs the request in curl format' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('VAOS_DEBUG').and_return('true')
        VCR.use_cassette('vaos/fhir/read_organization_200', match_requests_on: %i[method path query]) do
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
      xit 'raises a backend exception with key VAOS_502' do
        VCR.use_cassette('vaos/fhir/search_organization_500', match_requests_on: %i[method path query]) do
          expect { subject.search({ 'identifier' => '353000' }) }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) { |e| expect(e.key).to eq('VAOS_502') }
        end
      end
    end

    context 'with valid args' do
      let(:expected_body) do
        YAML.load_file(
          Rails.root.join(
            'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'search_organization_200.yml'
          )
        )['http_interactions'].first.dig('response', 'body', 'string')
      end

      xit 'returns the JSON response body from the VAMF response' do
        VCR.use_cassette('vaos/fhir/search_organization_200', match_requests_on: %i[method path query]) do
          response = subject.search({ 'identifier' => '983,984' })
          expect(response.body).to eq(expected_body)
        end
      end
    end
  end
end
