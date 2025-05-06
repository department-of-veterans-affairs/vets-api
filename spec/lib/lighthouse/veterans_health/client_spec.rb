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

  describe 'making requests' do
    let(:jwt) { 'fake_client_assurance_token' }
    let(:jwt_double) { double('JWT Wrapper', token: jwt) }
    let(:bearer_token_object) { double('bearer response', body: { 'access_token' => 'blah' }) }

    context 'valid requests' do
      let(:generic_response) do
        double('lighthouse response', status: 200, body: { generic: 'response', link: [] }.as_json)
      end

      before do
        allow(Lighthouse::VeteransHealth::JwtWrapper).to receive(:new).and_return(jwt_double)
        allow(@client).to receive_messages(perform: generic_response, authenticate: bearer_token_object)
      end

      describe 'when requesting medication_requests' do
        it 'authenticates to Lighthouse and retrieves a bearer token' do
          @client.list_medication_requests
          expect(@client.instance_variable_get(:@bearer_token)).to eq 'blah'
        end

        it 'sets the headers to include the bearer token' do
          headers = {
            'Accept' => 'application/json',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Vets.gov Agent',
            Authorization: 'Bearer blah'
          }

          @client.list_medication_requests
          expect(@client.instance_variable_get(:@headers_hash)).to eq headers
        end
      end

      describe 'when the caller requests the DiagnosticReports resource' do
        let(:diagnostic_report_api_path) { 'services/fhir/v0/r4/DiagnosticReport' }
        let(:params_hash) do
          { patient: @client.instance_variable_get(:@icn),
            _count: 100 }
        end

        it 'invokes the Lighthouse Veterans Health API MedicationRequest endpoint' do
          expect_any_instance_of(
            Lighthouse::VeteransHealth::Client
          ).to receive(:perform_get).with(diagnostic_report_api_path, params_hash).and_call_original
          @client.list_diagnostic_reports(count: 100)
        end

        it 'returns the api response' do
          expect(@client.list_diagnostic_reports).to eq generic_response
        end

        context 'when the response is larger than one page' do
          let(:response_with_pages) do
            double(
              'lighthouse response',
              status: 200,
              body: { entry: [{ first: 'page' }],
                      link: [{ relation: 'next',
                               url: 'https://api.fake/DiagnosticReport?patient=fake&page=2' }] }.as_json
            )
          end

          let(:next_response) do
            double(
              'lighthouse response',
              status: 200,
              body: { entry: [{ second: 'page' }],
                      link: [{ relation: 'next',
                               url: 'https://api.fake/DiagnosticReport?patient=fake&page=3' }] }.as_json
            )
          end

          let(:last_response) do
            double(
              'lighthouse response',
              status: 200,
              body: { entry: [{ last: 'page' }], link: [] }.as_json
            )
          end

          before do
            allow(@client).to receive(:perform).and_return response_with_pages, next_response, last_response
          end

          it 'returns all entries from every page within the single response' do
            expected_entries = [
              { first: 'page' },
              { second: 'page' },
              { last: 'page' }
            ].as_json
            expect(@client.list_diagnostic_reports.body['entry']).to match expected_entries
          end
        end
      end

      describe 'when the caller requests the BP Observations resource' do
        let(:observations_api_path) { 'services/fhir/v0/r4/Observation' }
        let(:params_hash) do
          {
            patient: @client.instance_variable_get(:@icn),
            category: 'vital-signs',
            code: '85354-9',
            _count: 100
          }
        end

        it 'invokes the Lighthouse Veterans Health API Observation endpoint' do
          expect_any_instance_of(Lighthouse::VeteransHealth::Client).to receive(
            :perform_get
          ).with(observations_api_path, params_hash).and_call_original
          @client.list_bp_observations
        end

        it 'returns the api response' do
          expect(@client.list_bp_observations).to eq generic_response
        end
      end

      describe 'when the caller requests the MedicationRequest resource' do
        let(:medications_api_path) { 'services/fhir/v0/r4/MedicationRequest' }
        let(:params_hash) do
          { patient: @client.instance_variable_get(:@icn),
            _count: 100 }
        end

        it 'invokes the Lighthouse Veterans Health API MedicationRequest endpoint' do
          expect_any_instance_of(
            Lighthouse::VeteransHealth::Client
          ).to receive(:perform_get).with(medications_api_path, params_hash).and_call_original
          @client.list_medication_requests
        end

        it 'returns the api response' do
          expect(@client.list_medication_requests).to eq generic_response
        end

        context 'when the response is larger than one page' do
          let(:response_with_pages) do
            double(
              'lighthouse response',
              status: 200,
              body: { entry: [{ first: 'page' }],
                      link: [{ relation: 'next',
                               url: 'https://api.fake/MedicationRequest?patient=fake&page=2' }] }.as_json
            )
          end

          let(:next_response) do
            double(
              'lighthouse response',
              status: 200,
              body: { entry: [{ second: 'page' }],
                      link: [{ relation: 'next',
                               url: 'https://api.fake/MedicationRequest?patient=fake&page=3' }] }.as_json
            )
          end

          let(:last_response) do
            double(
              'lighthouse response',
              status: 200,
              body: { entry: [{ last: 'page' }], link: [] }.as_json
            )
          end

          before do
            allow(@client).to receive(:perform).and_return response_with_pages, next_response, last_response
          end

          it 'returns all entries from every page within the single response' do
            expected_entries = [
              { first: 'page' },
              { second: 'page' },
              { last: 'page' }
            ].as_json
            expect(@client.list_medication_requests.body['entry']).to match expected_entries
          end
        end
      end

      describe '#list_conditions' do
        let(:conditions_api_path) { 'services/fhir/v0/r4/Condition' }
        let(:params_hash) do
          { patient: @client.instance_variable_get(:@icn),
            _count: 100 }
        end

        it 'invokes the Lighthouse Veterans Health API Condition endpoint' do
          expect_any_instance_of(
            Lighthouse::VeteransHealth::Client
          ).to receive(:perform_get).with(conditions_api_path, params_hash).and_call_original
          @client.list_conditions
        end

        it 'returns the api response' do
          expect(@client.list_conditions).to eq generic_response
        end
      end
    end

    context 'unsuccessful requests' do
      describe 'when a valid request to Lighthouse times out' do
        before do
          allow(@client).to receive(:perform).and_raise Faraday::TimeoutError
          allow(Lighthouse::VeteransHealth::JwtWrapper).to receive(:new).and_return(jwt_double)
          allow(@client).to receive(:authenticate).and_return bearer_token_object
        end

        it 'raises an exception and message' do
          expect { @client.list_medication_requests }.to raise_exception(Faraday::TimeoutError, 'timeout')
        end
      end
    end
  end
end
