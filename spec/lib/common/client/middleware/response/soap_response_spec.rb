# frozen_string_literal: true

require 'rails_helper'
require 'common/client/middleware/response/soap_parser'

describe Common::Client::Middleware::Response::SOAPParser do
  let(:connection) do
    Faraday.new do |conn|
      conn.use Common::Client::Middleware::Response::SOAPParser
      conn.adapter Faraday.default_adapter
    end
  end

  context 'with an XML prolog' do
    before do
      stub_request(:get, 'http://somewhere.gov').to_return(
        status: 200,
        headers: {
          'Content-Type' => 'text/xml'
        },
        body: '<?xml version="1.0" encoding="UTF-8"?><header foo="bar"/><body><name type="given">Steve</name></body>'
      )
    end

    it 'parses the xml correctly' do
      response = connection.get 'http://somewhere.gov'
      expect(response.env[:body].locate('body/name').first.attributes).to eq(type: 'given')
    end
  end

  context 'without an XML prolog' do
    before do
      stub_request(:get, 'http://somewhere.gov').to_return(
        status: 200,
        headers: {
          'Content-Type' => 'text/xml'
        },
        body: '<header foo="bar"/><body><name type="given">Steve</name></body>'
      )
    end

    it 'parses the xml correctly' do
      response = connection.get 'http://somewhere.gov'
      expect(response.env[:body].locate('body/name').first.attributes).to eq(type: 'given')
    end
  end

  context 'when there is a 500' do
    before do
      stub_request(:get, 'http://somewhere.gov').to_return(
        status: 500,
        headers: {
          'Content-Type' => 'text/xml'
        },
        body: 'foo'
      )
    end

    it 'logs the error to sentry' do
      expect_any_instance_of(described_class).to receive(:log_message_to_sentry).with(
        'SOAP HTTP call failed',
        :error,
        url: 'http://somewhere.gov',
        status: 500,
        body: 'foo'
      ).once

      expect { connection.get 'http://somewhere.gov' }.to raise_error(
        Common::Client::Errors::HTTPError, 'SOAP HTTP call failed'
      )
    end
  end

  context 'when there is a 200 with a fault response body' do
    before do
      stub_request(:get, 'http://somewhere.gov').to_return(
        status: 200,
        headers: {
          'Content-Type' => 'text/xml'
        },
        body: File.read('spec/support/mvi/find_candidate_soap_fault.xml')
      )
    end

    it 'raises an MVI::Errors::HTTPError' do
      expect { connection.get 'http://somewhere.gov' }.to raise_error(
        Common::Client::Errors::HTTPError, 'SOAP service returned internal server error'
      )
    end
  end
end
