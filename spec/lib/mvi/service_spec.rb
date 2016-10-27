# frozen_string_literal: true
require 'rails_helper'
require 'mvi/service'
require 'mvi/messages/find_candidate_message'

describe MVI::Service do
  let(:user) do
    FactoryGirl.build(
      :user,
      first_name: 'Mitchell',
      last_name: 'Jenkins',
      middle_name: 'G',
      birth_date: Time.parse('1949-03-04').utc,
      ssn: '796122306'
    )
  end
  let(:message) do
    MVI::Messages::FindCandidateMessage.new(
      [user.first_name, user.middle_name], user.last_name, user.birth_date, user.ssn, user.gender
    )
  end
  let(:cert) { instance_double('OpenSSL::X509::Certificate') }
  let(:key) { instance_double('OpenSSL::PKey::RSA') }

  before(:each) do
    allow(File).to receive(:read).and_return('foo')
    allow(OpenSSL::X509::Certificate).to receive(:new).and_return(cert)
    allow(OpenSSL::PKey::RSA).to receive(:new).and_return(key)
  end

  describe '.options' do
    context 'when there are no SSL options' do
      it 'should only return the wsdl' do
        ClimateControl.modify MVI_CLIENT_CERT_PATH: nil,
                              MVI_CLIENT_KEY_PATH: nil do
          expect(MVI::Service.options).to eq(url: ENV['MVI_URL'])
        end
      end
    end
    context 'when there are SSL options' do
      it 'should return the wsdl, cert and key paths' do
        ClimateControl.modify MVI_CLIENT_CERT_PATH: '/certs/fake_cert.pem',
                              MVI_CLIENT_KEY_PATH: '/certs/fake_key.pem' do
          expect(MVI::Service.options).to eq(
            url: ENV['MVI_URL'],
            ssl: {
              client_cert: cert,
              client_key: key
            }
          )
        end
      end
    end
  end

  describe '.find_candidate' do
    context 'with a valid request' do
      it 'calls the find_candidate endpoint with a find candidate message' do
        VCR.use_cassette('mvi/find_candidate/valid') do
          response = subject.find_candidate(message)
          expect(response).to eq(
            edipi: nil,
            icn: '1008714701V416111^NI^200M^USVHA^P',
            mhv_id: nil,
            vba_corp_id: '9100792239^PI^200CORP^USVBA^A',
            status: 'active',
            given_names: %w(Mitchell G),
            family_name: 'Jenkins',
            gender: 'M',
            birth_date: '19490304',
            ssn: '796122306'
          )
        end
      end
    end

    context 'when a MVI invalid request response is returned' do
      it 'should raise a invalid request error' do
        invalid_xml = File.read('spec/support/mvi/find_candidate_invalid_request.xml')
        allow(message).to receive(:to_xml).and_return(invalid_xml)
        VCR.use_cassette('mvi/find_candidate/invalid') do
          expect(Rails.logger).to receive(:error).with(/mvi find_candidate invalid request structure:/)
          expect { subject.find_candidate(message) }.to raise_error(MVI::InvalidRequestError)
        end
      end
    end

    context 'when a MVI failure response is returned' do
      it 'should raise a request failure error' do
        invalid_xml = File.read('spec/support/mvi/find_candidate_invalid_request.xml')
        allow(message).to receive(:to_xml).and_return(invalid_xml)
        VCR.use_cassette('mvi/find_candidate/failure') do
          expect(Rails.logger).to receive(:error).with(/mvi find_candidate request failure/)
          expect { subject.find_candidate(message) }.to raise_error(MVI::RequestFailureError)
        end
      end
    end

    context 'when a status of 500 is returned' do
      it 'should raise a request failure error' do
        allow(message).to receive(:to_xml).and_return('<nobeuno></nobeuno>')
        VCR.use_cassette('mvi/find_candidate/five_hundred') do
          expect { subject.find_candidate(message) }.to raise_error(MVI::HTTPError)
        end
      end
    end
  end

  describe MVI::RecordNotFound do
    let(:query_json) { File.read('spec/support/mvi/query.json') }
    let(:xml) { '<env:Envelope></env:Envelope>' }
    let(:response) { instance_double('MVI::Responses::FindCandidate') }
    subject { MVI::RecordNotFound.new('an error message', response) }

    before(:each) do
      allow(response).to receive(:query).and_return(File.read('spec/support/mvi/query.json'))
      allow(response).to receive(:original_response).and_return(xml)
    end

    it 'includes the query as json' do
      expect(subject.query).to eq(query_json)
    end

    it 'includes the original response as xml' do
      expect(subject.original_response).to eq(xml)
    end
  end
end
