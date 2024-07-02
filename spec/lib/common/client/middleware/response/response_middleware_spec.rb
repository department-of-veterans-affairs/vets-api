# frozen_string_literal: true

require 'rails_helper'
require 'common/client/middleware/response/json_parser'
require 'common/client/middleware/response/mhv_errors'
require 'common/client/middleware/response/raise_custom_error'
require 'common/client/middleware/response/snakecase'
require 'common/client/middleware/response/mhv_xml_html_errors'
require 'common/client/errors'

describe Common::Client::Middleware::Response do
  subject(:faraday_client) do
    Faraday.new do |conn|
      conn.response :snakecase
      conn.response :raise_custom_error, error_prefix: 'RX'
      conn.response :mhv_errors
      conn.response :mhv_xml_html_errors
      conn.response :json_parser

      conn.adapter :test do |stub|
        stub.get('ok') { [200, { 'Content-Type' => 'application/json' }, message_json] }
        stub.get('not-found') { [404, { 'Content-Type' => 'application/json' }, four_o_four] }
        stub.get('refill-fail') { [400, { 'Content-Type' => 'application/json' }, i18n_type_error] }
        stub.get('mhv-generic-html') { [400, { 'Content-Type' => 'application/html' }, mhv_generic_html] }
        stub.get('mhv-generic-xml') { [400, { 'Content-Type' => 'application/xml' }, mhv_generic_html] }
      end
    end
  end

  let(:message_json) { attributes_for(:message).to_json }
  let(:four_o_four) { { errorCode: 400, message: 'Record Not Found', developerMessage: 'blah' }.to_json }
  let(:i18n_type_error) { { errorCode: 139, message: 'server response', developerMessage: 'blah' }.to_json }
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

  context 'unparsable errors' do
    let(:detail) { '"Received an error response that could not be processed"' }
    let(:code) { '"VA900"' }
    let(:source) { '"MHV provided unparsable error response, check logs for original request body."' }
    let(:xml_or_html_response) do
      "BackendServiceException: {:status=>400, :detail=>#{detail}, :code=>#{code}, :source=>#{source}}"
    end

    it 'can handle generic html errors' do
      expect { faraday_client.get('mhv-generic-html') }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(xml_or_html_response)
      end
    end

    it 'can handle generic xml errors' do
      expect { faraday_client.get('mhv-generic-xml') }.to raise_error do |error|
        expect(error).to be_a(Common::Exceptions::BackendServiceException)
        expect(error.message).to eq(xml_or_html_response)
      end
    end
  end
end
