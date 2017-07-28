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
    message = 'BackendServiceException: VA900 - Record Not Found'
    expect { faraday_client.get("#{fake_host}/not-found") }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(message)
        expect(error.errors.first).to have_attributes(
          title: 'Operation failed',
          detail: 'Record Not Found',
          code: 'VA900',
          href: nil,
          id: nil,
          links: [],
          meta: nil,
          source: 'blah',
          status: '400'
        )
      end
  end

  it 'can override a response error using i18n' do
    message = 'BackendServiceException: RX139 - Prescription is not refillable'
    expect { faraday_client.get("#{fake_host}/refill-fail") }
      .to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(message)
        expect(error.errors.first).to have_attributes(
          title: 'Operation failed',
          detail: 'Prescription is not refillable',
          code: 'RX139',
          href: nil,
          id: nil,
          links: [],
          meta: nil,
          source: 'blah',
          status: '400'
        )
      end
  end

  context 'unparsable errors' do
    let(:xml_or_html_response) do
      "BackendServiceException: #{code} - #{detail}"
    end

    context 'of non 503 variety' do
      let(:detail) do
        'The server was acting as a gateway or proxy and received'\
        ' an invalid response from the upstream server.'
      end
      let(:code) { 'VA1000' }
      it 'can be properly handled when html' do
        expect { faraday_client.get("#{fake_host}/mhv-generic-html") }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
          expect(error.message).to eq(xml_or_html_response)
          expect(error.errors.first).to have_attributes(
            title: 'Bad gateway',
            detail: detail,
            code: code,
            href: nil,
            id: nil,
            links: [],
            meta: nil,
            source: 'Contact system administrator for additional details on what this error could mean.',
            status: '502'
          )
        end
      end

      it 'can be properly handled when xml' do
        expect { faraday_client.get("#{fake_host}/mhv-generic-xml") }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
          expect(error.message).to eq(xml_or_html_response)
          expect(error.errors.first).to have_attributes(
            title: 'Bad gateway',
            detail: detail,
            code: code,
            href: nil,
            id: nil,
            links: [],
            meta: nil,
            source: 'Contact system administrator for additional details on what this error could mean.',
            status: '502'
          )
        end
      end
    end

    context 'of 503 variety' do
      let(:detail) do
        'We could not process your request at this time. Please try again later.'
      end
      let(:code) { 'VA1003' }
      it 'can be properly handled when html' do
        expect { faraday_client.get("#{fake_host}/mhv-html-503") }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
          expect(error.message).to eq(xml_or_html_response)
          expect(error.errors.first).to have_attributes(
            title: 'Service temporarily unavailable',
            detail: detail,
            code: code,
            href: nil,
            id: nil,
            links: [],
            meta: nil,
            source: 'Contact system administrator for additional details on what this error could mean.',
            status: '503'
          )
        end
      end

      it 'can be properly handled when xml' do
        expect { faraday_client.get("#{fake_host}/mhv-xml-503") }.to raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
          expect(error.message).to eq(xml_or_html_response)
          expect(error.errors.first).to have_attributes(
            title: 'Service temporarily unavailable',
            detail: detail,
            code: code,
            href: nil,
            id: nil,
            links: [],
            meta: nil,
            source: 'Contact system administrator for additional details on what this error could mean.',
            status: '503'
          )
        end
      end
    end
  end
end
