# frozen_string_literal: true
require 'rails_helper'
require 'savon/mock/spec_helper'
require 'mvi/service'
require 'mvi/messages/find_candidate_message'

describe MVI::Service do
  include Savon::SpecHelper

  before(:all) { savon.mock! }
  after(:all) { savon.unmock! }

  let(:given_names) { %w(John William) }
  let(:family_name) { 'Smith' }
  let(:dob) { Time.new(1980, 1, 1).utc }
  let(:ssn) { '555-44-3333' }
  let(:gender) { 'M' }
  let(:message) { MVI::Messages::FindCandidateMessage.new(given_names, family_name, dob, ssn, gender) }

  describe '.load_wsdl' do
    it 'should have URI interpolated into wsdl' do
      expect(MVI::Service.client.instance_eval('@wsdl').document).to eq(
        ERB.new(File.read("#{Rails.root}/config/mvi_schema/IdmWebService_200VGOV.wsdl.erb")).result
      )
    end
  end

  describe '.find_candidate' do
    context 'with a valid request' do
      it 'calls the prpa_in201305_uv02 endpoint with a find candidate message' do
        xml = File.read("#{Rails.root}/spec/support/mvi/find_candidate_response.xml")
        savon.expects(:prpa_in201305_uv02).with(xml: message).returns(xml)
        response = MVI::Service.find_candidate(message)
        expect(response).to eq(
          edipi: '1234^NI^200DOD^USDOD^A',
          icn: '1000123456V123456^NI^200M^USVHA^P',
          mhv: '123456^PI^200MHV^USVHA^A',
          status: 'active',
          given_names: %w(John William),
          family_name: 'Smith',
          gender: 'M',
          dob: '19800101',
          ssn: '555-44-3333'
        )
      end
    end

    context 'when a MVI invalid request response is returned' do
      it 'should raise a invalid request error' do
        xml = File.read("#{Rails.root}/spec/support/mvi/find_candidate_invalid_response.xml")
        savon.expects(:prpa_in201305_uv02).with(xml: message).returns(xml)
        expect(Rails.logger).to receive(:error).with(/mvi find_candidate invalid request structure:/)
        expect { MVI::Service.find_candidate(message) }.to raise_error(MVI::InvalidRequestError)
      end
    end

    context 'when a MVI failure response is returned' do
      it 'should raise a request failure error' do
        xml = File.read("#{Rails.root}/spec/support/mvi/find_candidate_failure_response.xml")
        savon.expects(:prpa_in201305_uv02).with(xml: message).returns(xml)
        expect(Rails.logger).to receive(:error).with(/mvi find_candidate request failure/)
        expect { MVI::Service.find_candidate(message) }.to raise_error(MVI::RequestFailureError)
      end
    end

    context 'when a Savon::HTTPError error is returned' do
      it 'should raise a request failure error' do
        xml = File.read("#{Rails.root}/spec/support/mvi/find_candidate_failure_response.xml")
        response = { code: 500, headers: {}, body: xml }
        savon.expects(:prpa_in201305_uv02).returns(response)
        expect(Rails.logger).to receive(:error).with(/mvi find_candidate http error code: 500 message:/)
        expect { MVI::Service.find_candidate(message) }.to raise_error(MVI::HTTPError)
      end
    end

    context 'when a Savon::SOAPFault error is returned' do
      it 'should raise a request failure error' do
        xml = File.read("#{Rails.root}/spec/support/mvi/find_candidate_soap_fault.xml")
        response = { code: 500, headers: {}, body: xml }
        savon.expects(:prpa_in201305_uv02).returns(response)
        expect(Rails.logger).to receive(:error).with(/mvi find_candidate soap error code: 500/)
        expect { MVI::Service.find_candidate(message) }.to raise_error(MVI::SOAPError)
      end
    end
  end
end
