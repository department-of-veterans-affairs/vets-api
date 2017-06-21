# frozen_string_literal: true
require 'rails_helper'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/raise_error'
require 'common/client/middleware/response/snakecase'
require 'common/client/middleware/response/mhv_xml_html_errors'
require 'common/client/errors'

describe 'Response Middleware' do
  let(:message_json) { attributes_for(:message).to_json }
  let(:four_o_four) { { "errorCode": 400, "message": 'Record Not Found', "developerMessage": 'blah' }.to_json }
  let(:i18n_type_error) { { "errorCode": 139, "message": 'server response', "developerMessage": 'blah' }.to_json }
  let(:mhv_html_error) { '<html><head><title>Some Title</title></head><body>Some Error Message</body></html>' }
  let(:mhv_html_error_no_title) { '<html><body>Some Error Message</body></html>' }
  let(:mhv_generic_xml) { '<some-node><message>Some Message</message></some-node>' }
  let(:mhv_broken_xml) { '<some-node></some-node>' }

  let(:mhv_generic_xml_error_code) do
    '<Error><developerMessage></developerMessage><errorCode>103</errorCode><message>Error</message></Error>)'
  end

  let(:mhv_service_outage) do
    %(
      <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/">
        <soapenv:Body>
          <soapenv:Fault>
            <faultcode>soapenv:Server</faultcode>
            <faultstring>Policy Falsified</faultstring>
            <faultactor>https://essapi-sysb.myhealth.va.gov/mhv-api/patient/v1/session</faultactor>
            <detail>
              <l7:policyResult status="Assertion Falsified" xmlns:l7="http://www.layer7tech.com/ws/policy/fault"/>
            </detail>
          </soapenv:Fault>
        </soapenv:Body>
      </soapenv:Envelope>
    )
  end

  subject(:faraday_client) do
    Faraday.new do |conn|
      conn.response :snakecase
      conn.response :raise_error, error_prefix: 'RX'
      conn.response :mhv_errors
      conn.response :mhv_xml_html_errors
      conn.response :json_parser

      conn.adapter :test do |stub|
        stub.get('ok') { [200, { 'Content-Type' => 'application/json' }, message_json] }
        stub.get('not-found') { [404, { 'Content-Type' => 'application/json' }, four_o_four] }
        stub.get('refill-fail') { [400, { 'Content-Type' => 'application/json' }, i18n_type_error] }
        stub.get('mhv-broken-xml') { [400, { 'Content-Type' => 'application/xml' }, mhv_broken_xml] }
        stub.get('mhv-html-error') { [400, { 'Content-Type' => 'application/html' }, mhv_html_error] }
        stub.get('mhv-html-error-no-title') { [400, { 'Content-Type' => 'application/html' }, mhv_html_error_no_title] }
        stub.get('mhv-generic-xml') { [400, { 'Content-Type' => 'application/xml' }, mhv_generic_xml] }
        stub.get('mhv-generic-xml-error-code') do
          [400, { 'Content-Type' => 'application/xml' }, mhv_generic_xml_error_code]
        end
        stub.get('mhv-service-outage') { [400, { 'Content-Type' => 'application/xml' }, mhv_service_outage] }
      end
    end
  end

  it 'parses json successfully' do
    client_response = faraday_client.get('ok')
    expect(client_response.body).to be_a(Hash)
    expect(client_response.body.keys).to include(:id, :subject, :category, :body)
    expect(client_response.status).to eq(200)
  end

  it 'raises client response error' do
    message = 'BackendServiceException: {:status=>404, :detail=>"Record Not Found", :code=>"VA900", :source=>"blah"}'
    expect { faraday_client.get('not-found') }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message)
          .to eq(message)
        expect(error.errors.first[:detail])
          .to eq('Record Not Found')
      end
  end

  it 'can override a response error using i18n' do
    message = 'BackendServiceException: {:status=>400, :detail=>"server response", :code=>"RX139", :source=>"blah"}'
    expect { faraday_client.get('refill-fail') }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message)
          .to eq(message)
        expect(error.errors.first[:detail])
          .to eq('Prescription is not refillable')
      end
  end

  let(:generic_response) do
    'BackendServiceException: {:status=>400, '\
    ':detail=>"Received an error response that could not be processed", '\
    ':code=>"VA900", :source=>nil}'
  end

  context 'html errors' do
    it 'can handle html errors using a title' do
      message = 'BackendServiceException: {:status=>400, :detail=>"Some Title", :code=>"VA900", :source=>nil}'

      expect(Rails.logger).to receive(:error)
      expect { faraday_client.get('mhv-html-error') }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(message)
      end
    end

    it 'can handle html errors without a title' do
      expect(Rails.logger).to receive(:error)
      expect { faraday_client.get('mhv-html-error-no-title') }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(generic_response)
      end
    end
  end

  context 'xml errors' do
    it 'can handle broken xml' do
      rescued_response = 'BackendServiceException: {:status=>400, '\
      ':detail=>"Received an error response that could not be processed", '\
      ':code=>"VA900", :source=>"Check Logs for: Could not parse XML/HTML"}'
      allow_any_instance_of(Common::Client::Middleware::Response::MhvXmlHtmlErrors)
        .to receive(:log_message_to_sentry)
              .with(mhv_broken_xml, :error)
              .and_raise(ArgumentError, 'malformed format string - %"')

      allow_any_instance_of(Common::Client::Middleware::Response::MhvXmlHtmlErrors)
        .to receive(:log_message_to_sentry)
              .with('Could not parse XML/HTML', :warning, { original_status: 400, original_body: mhv_broken_xml })
              .and_return('')

      expect(Rails.logger).to receive(:error).twice
      expect { faraday_client.get('mhv-broken-xml') }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(rescued_response)
      end
    end

    it 'can handle generic xml errors' do
      expect(Rails.logger).to receive(:error)
      expect { faraday_client.get('mhv-generic-xml') }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(generic_response)
      end
    end

    it 'can handle xml errors with error codes and messages' do
      message = %(BackendServiceException: {:status=>400, :detail=>"Error", :code=>"VA900", :source=>""})
      expect { faraday_client.get('mhv-generic-xml-error-code') }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(message)
        expect(error.errors.first[:detail]).to eq('Error')
      end
    end

    it 'can handle mhv service outage' do
      expect { faraday_client.get('mhv-service-outage') }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.errors.first[:detail]).to eq('MHV Service Outage')
      end
    end
  end
end
