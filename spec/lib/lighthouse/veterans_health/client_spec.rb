# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/veterans_health/client'

RSpec.describe Lighthouse::VeteransHealth::Client do
  # setting the client only once for this test set, as it mimics how it's
  # used in the Sidekiq worker disability_compensation_fast_track_job.rb

  before(:all) do
    @client = Lighthouse::VeteransHealth::Client.new(12_345)
  end

  context 'initialization' do
    describe 'when the caller passes a valid icn' do
      it 'initializes the client with the icn set' do
        expect(@client.instance_variable_get(:@icn)).to eq 12_345
      end
    end

    describe 'when the caller passes no icn' do
      it 'raises an ArgumentError to the caller' do
        expect do
          Lighthouse::VeteransHealth::Client.new(nil)
        end.to raise_error(ArgumentError, 'no ICN passed in for LH API request.')
      end
    end

    describe 'when the caller passes a blank icn' do
      it 'raises an ArgumentError to the caller' do
        expect do
          Lighthouse::VeteransHealth::Client.new(' ')
        end.to raise_error(ArgumentError, 'no ICN passed in for LH API request.')
      end
    end
  end

  describe '#get_resource' do
    let(:jwt) { 'fake_client_assurance_token' }
    let(:jwt_double) { double('JWT Wrapper', token: jwt) }
    let(:bearer_token_object) { double('bearer response', body: { 'access_token' => 'blah' }) }

    context 'valid requests' do
      let(:generic_response) { { status: 200, body: { generic: 'response' } } }

      before do
        allow(@client).to receive(:perform).and_return generic_response
        allow(Lighthouse::VeteransHealth::JwtWrapper).to receive(:new).and_return(jwt_double)
        allow(@client).to receive(:authenticate).and_return bearer_token_object
      end

      describe 'when requesting any valid resource' do
        let(:random_resource_str) do
          %w[observations medications OBSERVATIONS MeDICATions].sample
        end

        it 'authenticates to Lighthouse and retrieves a bearer token' do
          @client.get_resource(random_resource_str)
          expect(@client.instance_variable_get(:@bearer_token)).to eq 'blah'
        end

        it 'sets the headers to include the bearer token' do
          headers = {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Vets.gov Agent',
            'Authorization': 'Bearer blah'
          }

          @client.get_resource(random_resource_str)
          expect(@client.instance_variable_get(:@headers_hash)).to eq headers
        end
      end

      describe 'when the caller requests the Observations resource' do
        let(:observations_api_path) { 'services/fhir/v0/r4/Observation' }
        let(:params_hash) do
          {
            patient: @client.instance_variable_get(:@icn),
            category: 'vital-signs',
            code: '85354-9'
          }
        end

        it 'invokes the Lighthouse Veterans Health API Observation endpoint' do
          expect_any_instance_of(Lighthouse::VeteransHealth::Client).to receive(
            :perform_get
          ).with(observations_api_path, params_hash)
          @client.get_resource('observations')
        end

        it 'returns the api response' do
          expect(@client.get_resource('observations')).to eq generic_response
        end
      end

      describe 'when the caller requests the MedicationRequest resource' do
        let(:medications_api_path) { 'services/fhir/v0/r4/MedicationRequest' }
        let(:params_hash) { { 'patient': @client.instance_variable_get(:@icn) } }

        it 'invokes the Lighthouse Veterans Health API MedicationRequest endpoint' do
          expect_any_instance_of(
            Lighthouse::VeteransHealth::Client
          ).to receive(:perform_get).with(medications_api_path, params_hash)
          @client.get_resource('medications')
        end
      end
    end

    context 'unsuccessful requests' do
      describe 'when an unsupported resource is requested' do
        it 'raises an error and message' do
          expect { @client.get_resource('whatever') }.to raise_error(ArgumentError, 'unsupported resource type')
        end
      end

      describe 'when a valid request to Lighthouse times out' do
        before do
          allow(@client).to receive(:perform).and_raise Faraday::TimeoutError
          allow(Lighthouse::VeteransHealth::JwtWrapper).to receive(:new).and_return(jwt_double)
          allow(@client).to receive(:authenticate).and_return bearer_token_object
        end

        it 'raises an exception and message' do
          expect { @client.get_resource('medications') }.to raise_exception(Faraday::TimeoutError, 'timeout')
        end
      end
    end
  end
end
