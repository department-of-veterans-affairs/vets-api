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

    context 'when no subject is returned in the response body' do
      let(:user) do
        FactoryGirl.build(
          :user,
          first_name: 'Earl',
          last_name: 'Stephens',
          middle_name: 'M',
          birth_date: Time.parse('1978-06-11').utc,
          ssn: '796188587'
        )
      end
      let(:message) do
        MVI::Messages::FindCandidateMessage.new(
          [user.first_name, user.middle_name], user.last_name, user.birth_date, user.ssn, user.gender
        )
      end
      it 'raises an MVI::RecordNotFound error' do
        VCR.use_cassette('mvi/find_candidate/no_subject') do
          expect { subject.find_candidate(message) }.to raise_error(MVI::RecordNotFound)
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
      it 'raises an MVI::HTTPError' do
        VCR.use_cassette('mvi/find_candidate/internal_server_error') do
          expect(Rails.logger).to receive(:error).with('MVI fault code: env:Server').once
          expect(Rails.logger).to receive(:error).with('MVI fault string: Internal Error (from server)').once
          expect { subject.find_candidate(message) }.to raise_error(MVI::HTTPError, 'MVI internal server error')
        end
      end
    end

    context 'when MVI multiple match failure response' do
      it 'raises MVI::RecordNotFound' do
        VCR.use_cassette('mvi/find_candidate/failure_multiple_matches') do
          expect { subject.find_candidate(message) }.to raise_error(MVI::RecordNotFound)
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
