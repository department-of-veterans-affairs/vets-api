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
      birth_date: '1949-03-04',
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
    stub_const('MVI::Settings::SSL_CERT', cert)
    stub_const('MVI::Settings::SSL_KEY', key)
  end

  describe '.options' do
    context 'when there are no SSL options' do
      it 'should only return the wsdl' do
        stub_const('MVI::Settings::SSL_CERT', nil)
        stub_const('MVI::Settings::SSL_KEY', nil)
        expect(MVI::Service.options).to eq(url: ENV['MVI_URL'])
      end
    end
    context 'when there are SSL options' do
      it 'should return the wsdl, cert and key paths' do
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

  describe '.find_candidate' do
    context 'with a valid request' do
      it 'calls the find_candidate endpoint with a find candidate message' do
        VCR.use_cassette('mvi/find_candidate/valid') do
          response = subject.find_candidate(message)
          expect(response).to eq(
            edipi: nil,
            icn: '1008714701V416111^NI^200M^USVHA^P',
            mhv_ids: nil,
            vba_corp_id: '9100792239^PI^200CORP^USVBA^A',
            active_status: 'active',
            given_names: %w(Mitchell G),
            family_name: 'Jenkins',
            gender: 'M',
            birth_date: '19490304',
            ssn: '796122306'
          )
        end
      end
    end

    context 'with a valid request without gender' do
      let(:user) do
        FactoryGirl.build(
          :user,
          first_name: 'Mitchell',
          last_name: 'Jenkins',
          middle_name: 'G',
          birth_date: '1949-03-04',
          ssn: '796122306',
          gender: nil
        )
      end
      let(:message) do
        MVI::Messages::FindCandidateMessage.new(
          [user.first_name, user.middle_name], user.last_name, user.birth_date, user.ssn, user.gender
        )
      end
      it 'calls the find_candidate endpoint with a find candidate message' do
        VCR.use_cassette('mvi/find_candidate/valid_no_gender') do
          response = subject.find_candidate(message)
          expect(response).to eq(
            edipi: nil,
            icn: '1008714701V416111^NI^200M^USVHA^P',
            mhv_ids: nil,
            vba_corp_id: '9100792239^PI^200CORP^USVBA^A',
            active_status: 'active',
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
          expect { subject.find_candidate(message) }.to raise_error(SOAP::Errors::InvalidRequestError)
        end
      end
    end

    context 'when a MVI failure response is returned' do
      it 'should raise a request failure error' do
        invalid_xml = File.read('spec/support/mvi/find_candidate_invalid_request.xml')
        allow(message).to receive(:to_xml).and_return(invalid_xml)
        VCR.use_cassette('mvi/find_candidate/failure') do
          expect { subject.find_candidate(message) }.to raise_error(SOAP::Errors::RequestFailureError)
        end
      end
    end

    context 'with an MVI timeout' do
      it 'should raise a service error' do
        allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        expect(Rails.logger).to receive(:error).with('MVI find_candidate timeout')
        expect { subject.find_candidate(message) }.to raise_error(SOAP::Errors::ServiceError)
      end
    end

    context 'when a status of 500 is returned' do
      it 'should raise a request failure error' do
        allow(message).to receive(:to_xml).and_return('<nobeuno></nobeuno>')
        VCR.use_cassette('mvi/find_candidate/five_hundred') do
          expect { subject.find_candidate(message) }.to raise_error(SOAP::Errors::HTTPError)
        end
      end
    end

    context 'when no subject is returned in the response body' do
      let(:user) do
        FactoryGirl.build(
          :user,
          first_name: 'Earl',
          last_name: 'Stephens',
          middle_name: 'M',
          birth_date: '1978-06-11',
          ssn: '796188587'
        )
      end
      let(:message) do
        MVI::Messages::FindCandidateMessage.new(
          [user.first_name, user.middle_name], user.last_name, user.birth_date, user.ssn, user.gender
        )
      end
      it 'raises an SOAP::Errors::RecordNotFound error' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          expect { subject.find_candidate(message) }.to raise_error(SOAP::Errors::RecordNotFound)
        end
      end

      context 'with an ongoing breakers outage' do
        it 'returns the correct thing' do
          MVI::Service.breakers_service.begin_forced_outage!
          expect { subject.find_candidate(message) }.to raise_error(Breakers::OutageException)
        end
      end
    end

    context 'when MVI returns 500 but VAAFI sends 200' do
      it 'raises an SOAP::Errors::HTTPError' do
        VCR.use_cassette('mvi/find_candidate/internal_server_error') do
          expect(Rails.logger).to receive(:error).with('MVI fault code: env:Server').once
          expect(Rails.logger).to receive(:error).with('MVI fault string: Internal Error (from server)').once
          expect do
            subject.find_candidate(message)
          end.to raise_error(SOAP::Errors::HTTPError, 'MVI internal server error')
        end
      end
    end

    context 'when MVI multiple match failure response' do
      it 'raises SOAP::Errors::RecordNotFound' do
        VCR.use_cassette('mvi/find_candidate/failure_multiple_matches') do
          expect do
            subject.find_candidate(message)
          end.to raise_error(SOAP::Errors::RecordNotFound)
        end
      end
    end
  end
end
