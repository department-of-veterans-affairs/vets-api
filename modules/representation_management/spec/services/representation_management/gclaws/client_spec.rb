# frozen_string_literal: true

require 'rails_helper'
require 'faraday'
require 'json'

RSpec.describe RepresentationManagement::GCLAWS::Client do
  subject { described_class }

  describe '.get_accredited_entities' do
    context 'when the type is invalid' do
      let(:type) { 'invalid' }

      it 'returns an empty hash' do
        response = subject.get_accredited_entities(type:)
        expect(response).to eq({})
      end
    end

    context 'when the type is valid' do
      let(:type) { 'agents' }
      let(:parsed_body) { { field: 'value' } }

      context 'when the request is successful' do
        it 'returns a successful response' do
          stub_request(:get, Settings.gclaws.accreditation.agents.url)
            .with(query: { 'page' => 1, 'pageSize' => 100, 'sortColumn' => 'LastName', 'sortOrder' => 'ASC' })
            .to_return(status: 200, body: parsed_body.to_json, headers: { 'Content-Type' => 'application/json' })

          response = subject.get_accredited_entities(type:)

          expect(response.status).to eq(200)
          expect(response.body).to eq(parsed_body.stringify_keys)
        end
      end

      context 'when the connection fails' do
        it 'logs the error and returns a service unavailable status' do
          stub_request(:get, Settings.gclaws.accreditation.agents.url)
            .with(query: { 'page' => 1, 'pageSize' => 100, 'sortColumn' => 'LastName', 'sortOrder' => 'ASC' })
            .to_raise(Faraday::ConnectionFailed.new('GCLAWS Accreditation unavailable'))

          expect(Rails.logger).to receive(:error).with("GCLAWS Accreditation connection failed for #{type}")

          response = subject.get_accredited_entities(type:)

          expect(response.status).to eq(:service_unavailable)
          expect(JSON.parse(response.body)['errors']).to eq('GCLAWS Accreditation unavailable')
        end
      end

      context 'when the request times out' do
        it 'logs the error and returns a request timeout status' do
          stub_request(:get, Settings.gclaws.accreditation.agents.url)
            .with(query: { 'page' => 1, 'pageSize' => 100, 'sortColumn' => 'LastName', 'sortOrder' => 'ASC' })
            .to_raise(Faraday::TimeoutError.new('GCLAWS Accreditation request timed out'))

          expect(Rails.logger).to receive(:error).with(
            "GCLAWS Accreditation request timed out for #{type}"
          )

          response = subject.get_accredited_entities(type:)

          expect(response.status).to eq(:request_timeout)
          expect(JSON.parse(response.body)['errors']).to eq('GCLAWS Accreditation request timed out')
        end
      end
    end
  end
end
