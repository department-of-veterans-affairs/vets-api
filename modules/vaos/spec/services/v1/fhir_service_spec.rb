# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V1::FHIRService do
  subject { VAOS::V1::FHIRService.new(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#read' do
    context 'when VAMF returns a 404' do
      it 'raises a backend exception with key VAOS_404' do
        VCR.use_cassette('vaos/fhir/404', match_requests_on: %i[method uri]) do
          expect { subject.read(:Organization, 999_999) }.to raise_error(
            Common::Exceptions::BackendServiceException
          ) { |e| expect(e.key).to eq('VAOS_404') }
        end
      end
    end

    context 'with an invalid resource type' do
      it 'raises an invalid field value exception' do
        expect { subject.read(:House, 353_830) }.to raise_error(
          Common::Exceptions::InvalidFieldValue
        ) { |e| expect(e.errors.first.detail).to eq('"House" is not a valid value for "resource_type"') }
      end
    end

    context 'with valid args' do
      let(:expected_body) do
        YAML.load_file(
          Rails.root.join(
            'spec', 'support', 'vcr_cassettes', 'vaos', 'fhir', 'get_organization.yml'
          )
        )['http_interactions'].first.dig('response', 'body', 'string')
      end

      it 'returns the JSON response body from the VAMF response' do
        VCR.use_cassette('vaos/fhir/get_organization', match_requests_on: %i[method uri]) do
          response = subject.read(:Organization, 353_830)
          expect(response.body).to eq(expected_body)
        end
      end
    end
  end
end
