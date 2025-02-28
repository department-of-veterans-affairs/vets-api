# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/error/soap_error_handler'
require 'bgs_service/intent_to_file_web_service'

describe ClaimsApi::IntentToFileWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:soap_error_handler) { ClaimsApi::SoapErrorHandler.new }

  describe '#insert_intent_to_file' do
    let(:itf) { build(:intent_to_file) }
    let(:participant_id) { '13367440' }
    let(:type) { 'C' }
    let(:ssn) { '796130115' }
    let(:options) do
      {
        intent_to_file_type_code: type,
        participant_vet_id: '600043201',
        received_date: '2025-02-07T13:12:40+00:00',
        submitter_application_icn_type_code: 'LH-B',
        ssn:,
        participant_claimant_id: '600043201'
      }
    end
    let(:erroneous_options) do
      {
        intent_to_file_type_code: 'S',
        participant_vet_id: '1234',
        received_date: Time.zone.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
        submitter_application_icn_type_code: ClaimsApi::IntentToFile::SUBMITTER_CODE,
        ssn: '5678'
      }
    end

    context 'happy path' do
      it 'returns an object with the appropriate attributes' do
        VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file') do
          res = subject.insert_intent_to_file(options)
          expect(res[:intent_to_file_id]).to eq('294045')
          expect(res[:ptcpnt_clmant_id]).to eq('600043201')
          expect(res[:ptcpnt_vet_id]).to eq('600043201')
        end
      end
    end

    context 'sad path' do
      it 'returns the correct error message when incorrect params are provided' do
        VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/insert_intent_to_file_500') do
          subject.insert_intent_to_file(erroneous_options)
        rescue => e
          expect(e).to be_a(Common::Exceptions::ServiceError)
          expect(e.message).to be('Unknown Service Error')
        end
      end
    end
  end

  describe '#find_intent_to_file_by_ptcpnt_id_itf_type_cd' do
    let(:participant_id) { '600061742' }
    let(:type) { 'C' }

    context 'happy path' do
      it 'returns an object with the appropriate attributes' do
        VCR.use_cassette('claims_api/bgs/intent_to_file_web_service/find_intent_to_file_by_ptcpnt_id_itf_type_cd') do
          res = subject.find_intent_to_file_by_ptcpnt_id_itf_type_cd(participant_id, type)
          expect(res[0][:intent_to_file_id]).to eq('287002')
        end
      end
    end

    context 'sad path' do
      it 'returns the correct error message when incorrect params are provided' do
        VCR.use_cassette(
          'claims_api/bgs/intent_to_file_web_service/find_intent_to_file_by_ptcpnt_id_itf_type_cd_500'
        ) do
          subject.find_intent_to_file_by_ptcpnt_id_itf_type_cd(participant_id, type)
        rescue => e
          expect(e).to be_a(Common::Exceptions::ServiceError)
          expect(e.message).to be('Unknown Service Error')
        end
      end
    end
  end
end
