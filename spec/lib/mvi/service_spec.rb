# frozen_string_literal: true
require 'rails_helper'
require 'savon/mock/spec_helper'
require 'mvi/service'
require 'mvi/messages/find_candidate_message'
require "#{Rails.root}/spec/support/mvi/mvi_response"

describe MVI::Service do
  include Savon::SpecHelper

  before(:all) { savon.mock! }
  after(:all) { savon.unmock! }

  let(:given_names) { %w(John William) }
  let(:family_name) { 'Smith' }
  let(:birth_date) { Time.new(1980, 1, 1).utc }
  let(:ssn) { '555-44-3333' }
  let(:gender) { 'M' }
  let(:message) { MVI::Messages::FindCandidateMessage.new(given_names, family_name, birth_date, ssn, gender) }

  describe '.load_wsdl' do
    it 'should have URI interpolated into wsdl' do
      expect(MVI::Service.client.instance_eval('@wsdl').document).to eq(
        ERB.new(File.read('config/mvi_schema/IdmWebService_200VGOV.wsdl.erb')).result
      )
    end
  end

  describe '.find_candidate' do
    context 'with a valid request' do
      it 'calls the prpa_in201305_uv02 endpoint with a find candidate message' do
        xml = File.read('spec/support/mvi/find_candidate_response.xml')
        savon.expects(:prpa_in201305_uv02).with(xml: message).returns(xml)
        response = MVI::Service.find_candidate(message)
        expect(response).to eq(
          edipi: '1234^NI^200DOD^USDOD^A',
          icn: '1000123456V123456^NI^200M^USVHA^P',
          mhv_id: '123456^PI^200MHV^USVHA^A',
          vba_corp_id: '12345678^PI^200CORP^USVBA^A',
          status: 'active',
          given_names: %w(John William),
          family_name: 'Smith',
          gender: 'M',
          birth_date: '19800101',
          ssn: '555443333'
        )
      end
    end

    context 'when a MVI invalid request response is returned' do
      it 'should raise a invalid request error' do
        xml = File.read('spec/support/mvi/find_candidate_invalid_response.xml')
        savon.expects(:prpa_in201305_uv02).with(xml: message).returns(xml)
        expect(Rails.logger).to receive(:error).with(/mvi find_candidate invalid request structure:/)
        expect { MVI::Service.find_candidate(message) }.to raise_error(MVI::InvalidRequestError)
      end
    end

    context 'when a MVI failure response is returned' do
      it 'should raise a request failure error' do
        xml = File.read('spec/support/mvi/find_candidate_failure_response.xml')
        savon.expects(:prpa_in201305_uv02).with(xml: message).returns(xml)
        expect(Rails.logger).to receive(:error).with(/mvi find_candidate request failure/)
        expect { MVI::Service.find_candidate(message) }.to raise_error(MVI::RequestFailureError)
      end
    end

    context 'when a Savon::HTTPError error is returned' do
      it 'should raise a request failure error' do
        xml = File.read('spec/support/mvi/find_candidate_failure_response.xml')
        response = { code: 500, headers: {}, body: xml }
        savon.expects(:prpa_in201305_uv02).returns(response)
        expect(Rails.logger).to receive(:error).with(/mvi find_candidate http error code: 500 message:/)
        expect { MVI::Service.find_candidate(message) }.to raise_error(MVI::HTTPError)
      end
    end

    context 'when a Savon::SOAPFault error is returned' do
      it 'should raise a request failure error' do
        xml = File.read('spec/support/mvi/find_candidate_soap_fault.xml')
        response = { code: 500, headers: {}, body: xml }
        savon.expects(:prpa_in201305_uv02).returns(response)
        expect(Rails.logger).to receive(:error).with(/mvi find_candidate soap error code: 500/)
        expect { MVI::Service.find_candidate(message) }.to raise_error(MVI::SOAPError)
      end
    end
  end

  describe MVI::RecordNotFound do
    let(:xml) { File.read('spec/support/mvi/find_candidate_response.xml') }
    let(:response) { MVI::Responses::FindCandidate.new(mvi_valid_response) }
    subject { MVI::RecordNotFound.new('an error message', response) }

    it 'includes the query' do
      expect(subject.query).to eq(
        initial_quantity: { :@value => '1' },
        modify_code: { :@code => 'MVI.COMP1' },
        parameter_list: {
          living_subject_name: {
            value: {
              given: %w(John William),
              family: 'Smith',
              :@use => 'L'
            },
            semantics_text: 'LivingSubject.name'
          },
          living_subject_birth_time: {
            value: {
              :@value => '19800101'
            },
            semantics_text: 'LivingSubject.birthTime'
          },
          living_subject_id: {
            value: {
              :@extension => '555-44-3333',
              :@root => '2.16.840.1.113883.4.1'
            },
            semantics_text: 'SSN'
          }
        },
        query_id: { :@extension => '18204', :@root => '2.16.840.1.113883.3.933' },
        status_code: { :@code => 'new' }
      )
    end

    it 'includes the original response' do
      expect(subject.original_response).to eq(xml)
    end
  end
end
