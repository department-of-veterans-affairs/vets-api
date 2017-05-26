# frozen_string_literal: true
require 'rails_helper'
require 'hca/esr/service'

describe HCA::ESR::Service do
  let(:xml_path) { 'SOAP-ENV:Envelope/SOAP-ENV:Body/getEESummaryResponse/summary' }
  describe '#get_form' do
    context 'with a valid request' do
      it 'returns the id and a timestamp' do
        VCR.use_cassette('hca/esr/get_form', match_requests_on: [:body]) do
          xml = subject.get_form(icn: '1111111111V222222').body
          expect(xml).to eq_text_at_path("#{xml_path}/enrollmentDeterminationInfo/recordCreatedDate",
                                         '2005-01-01T12:43:07.000-06:00')
          expect(xml).to eq_text_at_path("#{xml_path}/eligibilityVerificationInfo/eligibilityStatus",
                                         'VERIFIED')
        end
      end
    end
  end
end
