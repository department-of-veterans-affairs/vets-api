# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/error/soap_error_handler'
require 'bgs_service/vet_record_web_service'

describe ClaimsApi::VetRecordWebService do
  subject { described_class.new external_uid: 'xUid', external_key: 'xKey' }

  let(:soap_error_handler) { ClaimsApi::SoapErrorHandler.new }
  let(:poa) { create(:power_of_attorney) }

  before do
    poa.form_data = {
      representative: {
        poaCode: '072'
      }
    }
    poa.save!
  end

  describe '#update_birls_record(file_number, ssn, poa_code, poa_form)' do
    context 'update_birls_record with valid options' do
      it 'returns an object with the appropriate attributes' do
        VCR.use_cassette('claims_api/bgs/vet_record_web_service/update_birls_record') do
          res = subject.update_birls_record(file_number: '796104437',
                                            ssn: '796104437',
                                            poa_code: ['072'],
                                            poa_form: poa.form_data)
          expect(res[:return_code]).to eq('BMOD0001')
          expect(res[:return_message]).to eq('BIRLS Update successful')
        end
      end
    end

    context 'update_birls_record with empty options' do
      it 'returns the correct error message when incorrect params are provided' do
        VCR.use_cassette('claims_api/bgs/vet_record_web_service/invalid_update_birls_record') do
          res = subject.update_birls_record(poa_code: ['not-a-code', 'still-not-a-code'],
                                            file_number: 'not-a-number',
                                            ssn: 'not-ssn',
                                            poa_form: {})
          expect(res[:return_code]).to eq('BPNQ0100')
          expect(res[:return_message]).to eq('No BIRLS record found')
        rescue => e
          expect(e).to be_a(Common::Exceptions::ServiceError)
          expect(e.message).to be('Unprocessable Entity')
        end
      end
    end
  end
end
