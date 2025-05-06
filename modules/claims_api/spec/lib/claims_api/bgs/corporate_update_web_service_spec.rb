# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/error/soap_error_handler'
require 'bgs_service/corporate_update_web_service'

describe ClaimsApi::CorporateUpdateWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:soap_error_handler) { ClaimsApi::SoapErrorHandler.new }

  describe '#update_poa_access' do
    let(:poa) { build(:power_of_attorney) }
    let(:poa_code) { '074' }
    let(:participant_id) { '600061742' }

    context 'when given valid params(poa code, participlant id)' do
      it 'returns an object with the appropriate attributes' do
        VCR.use_cassette('claims_api/bgs/corporate_update_web_service/update_poa_access') do
          res = subject.update_poa_access(participant_id:, poa_code:)

          expect(res[:return_code]).to eq('GUIE50000')
          expect(res[:return_message]).to eq('Success')
          expect(res[:poa_name]).to eq('074 - AMERICAN LEGION')
        end
      end
    end

    context 'when given invalid params' do
      it 'returns the correct error message' do
        VCR.use_cassette('claims_api/bgs/corporate_update_web_service/update_poa_access_500') do
          subject.update_poa_access(participant_id: '38429', poa_code: '001')
        rescue => e
          expect(e).to be_a(Common::Exceptions::ServiceError)
          expect(e.message).to be('Unknown Service Error')
        end
      end
    end
  end
end
