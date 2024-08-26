# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/local_bgs_refactored/find_definition'

describe ClaimsApi::LocalBGSRefactored::FindDefinition do
  subject { described_class }

  before do
    Flipper.disable(:lighthouse_claims_api_hardcode_wsdl)
  end

  describe '#for_action' do
    context 'hardcoded WSDL' do
      before do
        Flipper.enable(:lighthouse_claims_api_hardcode_wsdl)
      end

      context 'OrgWebServiceBean' do
        let(:endpoint) { 'VDC/VeteranRepresentativeService' }
        let(:action) { 'readAllVeteranRepresentatives' }
        let(:key) { 'VeteranRepresentativeReturnList' }
        
        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['path']).to eq 'VeteranRepresentativeService'
        end
      end

      context 'VdcBean' do
        let(:endpoint) { 'VDC/ManageRepresentativeService' }
        let(:action) { 'readPOARequest' }
        let(:key) { 'POARequestRespondReturnVO' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'VDC'
          expect(parsed_result['service']['path']).to eq 'ManageRepresentativeService'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://gov.va.vba.benefits.vdc/services'
        end
      end
    end
  end

  describe '#for_service' do
    context 'hardcoded WSDL' do
      before do
        Flipper.enable(:lighthouse_claims_api_hardcode_wsdl)
      end

      context 'OrgWebService' do
        let(:endpoint) { 'VDC/VeteranRepresentativeService' }
        
        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VDC'
          expect(parsed_result['path']).to eq 'VeteranRepresentativeService'
        end
      end

      context 'VdcBean' do
        let(:endpoint) { 'VDC/ManageRepresentativeService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['path']).to eq 'ManageRepresentativeService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://gov.va.vba.benefits.vdc/services'
        end
      end
    end
  end
end
