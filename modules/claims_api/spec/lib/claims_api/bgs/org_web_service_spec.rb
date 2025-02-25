# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/error/soap_error_handler'
require 'bgs_service/org_web_service'

describe ClaimsApi::OrgWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:soap_error_handler) { ClaimsApi::SoapErrorHandler.new }

  describe '#find_poa_history_by_ptcpnt_id' do
    let(:participant_id) { '600061742' }

    context 'happy path' do
      it 'returns an object with the appropriate attributes' do
        VCR.use_cassette('claims_api/bgs/org_web_service/happy_path') do
          res = subject.find_poa_history_by_ptcpnt_id(participant_id)
          expect(res[:person_poa_history][:person_poa][0][:legacy_poa_cd]).to eq('074')
        end
      end
    end

    context 'sad path' do
      it 'returns the correct error message when incorrect params are provided' do
        VCR.use_cassette('claims_api/bgs/org_web_service/sad_path') do
          subject.find_poa_history_by_ptcpnt_id('not-an-id')
        rescue => e
          expect(e).to be_a(Common::Exceptions::ServiceError)
          expect(e.message).to be('Unprocessable Entity')
        end
      end
    end
  end
end
