# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/veteran_representative_service'

describe ClaimsApi::VeteranRepresentativeService do
  subject { described_class.new(external_uid: 'xUid', external_key: 'xKey') }

  before do
    stub_request(:get, 'https://fwdproxy-dev.vfs.va.gov:4447/endpoint?WSDL')
      .to_return(
        status: 200,
        body: <<~XML,
          <?xml version="1.0" encoding="UTF-8"?>
          <definitions xmlns="http://schemas.xmlsoap.org/wsdl/">
            <!-- fake WSDL -->
          </definitions>
        XML
        headers: { 'Content-Type' => 'text/xml' }
      )

    stub_request(:post, 'https://fwdproxy-dev.vfs.va.gov:4447/endpoint')
      .to_return(
        status: 200,
        body: <<~XML,
          <?xml version="1.0" encoding="UTF-8"?>
          <Envelope xmlns="http://schemas.xmlsoap.org/soap/envelope/">
            <Body>
              <testResponse>
                <result>success</result>
              </testResponse>
            </Body>
          </Envelope>
        XML
        headers: { 'Content-Type' => 'text/xml' }
      )
  end

  describe 'with a namespace param' do
    it 'does not raise ArgumentError' do
      expect do
        subject.send(:make_request, endpoint: 'endpoint', namespaces: { 'testspace' => '/test' },
                                    action: 'testAction',
                                    body: 'this is the body',
                                    key: 'ThisIsTheKey')
      end.not_to raise_error
    end
  end

  describe 'without the namespace param' do
    let(:params) { { ptcpnt_id: '123456' } }

    it 'raises ArgumentError' do
      expect do
        subject.send(:make_request, action: 'testAction', body: 'this is the body',
                                    key: 'ThisIsTheKey')
      end.to raise_error(ArgumentError)
    end
  end
end
