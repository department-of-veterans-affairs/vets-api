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

      context 'VnpAtchmsWebServiceBean' do
        let(:endpoint) { 'VnpAtchmsWebServiceBean/VnpAtchmsService' }
        let(:action) { 'vnpAtchmsCreate' }
        let(:key) { 'return' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'VnpAtchmsWebServiceBean'
          expect(parsed_result['service']['path']).to eq 'VnpAtchmsService'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://atchmsService.services.vonapp.vba.va.gov/'
        end
      end
    end
  end

  describe '#for_service' do
    context 'hardcoded WSDL' do
      before do
        Flipper.enable(:lighthouse_claims_api_hardcode_wsdl)
      end

      context 'VnpAtchmsService' do
        let(:endpoint) { 'VnpAtchmsWebServiceBean/VnpAtchmsService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VnpAtchmsWebServiceBean'
          expect(parsed_result['path']).to eq 'VnpAtchmsService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://atchmsService.services.vonapp.vba.va.gov/'
        end
      end
    end
  end
end
