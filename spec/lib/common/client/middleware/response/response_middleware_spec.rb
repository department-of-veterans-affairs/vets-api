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
  let(:mhv_generic_html) { '<html><body width=100%>Some Error Message</body></html>' }
  let(:mhv_generic_xml) do
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

  let(:fake_host) { 'http://host.com' }

  subject(:faraday_client) do
    Faraday.new do |conn|
      conn.use :breakers
      conn.response :snakecase
      conn.response :raise_error, error_prefix: 'RX'
      conn.response :mhv_errors
      conn.response :mhv_xml_html_errors, breakers_service: rx_breakers_service
      conn.response :json_parser

      conn.adapter :test do |stub|
        stub.get("#{fake_host}/ok") { [200, { 'Content-Type' => 'application/json' }, message_json] }
        stub.get("#{fake_host}/not-found") { [404, { 'Content-Type' => 'application/json' }, four_o_four] }
        stub.get("#{fake_host}/refill-fail") { [400, { 'Content-Type' => 'application/json' }, i18n_type_error] }
        stub.get("#{fake_host}/mhv-generic-html") { [400, { 'Content-Type' => 'application/html' }, mhv_generic_html] }
        stub.get("#{fake_host}/mhv-generic-xml") { [400, { 'Content-Type' => 'application/xml' }, mhv_generic_html] }
        stub.get("#{fake_host}/mhv-html-503") { [503, { 'Content-Type' => 'application/html' }, mhv_generic_html] }
        stub.get("#{fake_host}/mhv-xml-503") { [503, { 'Content-Type' => 'application/xml' }, mhv_generic_html] }
      end
    end
  end

  let(:rx_breakers_service) do
    path = URI.parse('http://host.com').path
    host = URI.parse('http://host.com').host
    matcher = proc do |request_env|
      request_env.url.host == host && request_env.url.path =~ /^#{path}/
    end

    exception_handler = proc do |exception|
      if exception.is_a?(Common::Exceptions::BackendServiceException)
        (500..599).cover?(exception.response_values[:status])
      else
        false
      end
    end

    Breakers::Service.new(
      name: 'RX',
      request_matcher: matcher,
      exception_handler: exception_handler
    )
  end

  it 'parses json successfully' do
    client_response = faraday_client.get("#{fake_host}/ok")
    expect(client_response.body).to be_a(Hash)
    expect(client_response.body.keys).to include(:id, :subject, :category, :body)
    expect(client_response.status).to eq(200)
  end

  it 'raises client response error' do
    message = 'BackendServiceException: {:status=>404, :detail=>"Record Not Found", :code=>"VA900", :source=>"blah"}'
    expect { faraday_client.get("#{fake_host}/not-found") }
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
    expect { faraday_client.get("#{fake_host}/refill-fail") }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message)
          .to eq(message)
        expect(error.errors.first[:detail])
          .to eq('Prescription is not refillable')
      end
  end

  context 'unparsable errors' do
    let(:detail) { '"Received an error response that could not be processed"' }
    let(:code) { '"VA900"' }
    let(:source) { '"MHV provided unparsable error response, check logs for original request body."' }
    let(:xml_or_html_response) do
      "BackendServiceException: {:status=>400, :detail=>#{detail}, :code=>#{code}, :source=>#{source}}"
    end

    it 'can handle generic html errors' do
      expect { faraday_client.get("#{fake_host}/mhv-generic-html") }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(xml_or_html_response)
      end
    end

    it 'can handle generic xml errors' do
      expect { faraday_client.get("#{fake_host}/mhv-generic-xml") }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(xml_or_html_response)
      end
    end

    it 'can handle generic html errors that are 503' do
      expect { faraday_client.get("#{fake_host}/mhv-html-503") }.to raise_error do |error|
        expect(error).to be_a(Breakers::OutageException)
        expect(error.message).to include('Outage detected on RX beginning at')
      end
    end

    it 'can handle generic xml errors that are 503' do
      expect { faraday_client.get("#{fake_host}/mhv-xml-503") }.to raise_error do |error|
        expect(error).to be_a(Breakers::OutageException)
        expect(error.message).to include('Outage detected on RX beginning at')
      end
    end
  end
end
