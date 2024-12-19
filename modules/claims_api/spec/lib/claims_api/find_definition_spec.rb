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

      context 'Vdc' do
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

      context 'VnpPersonService' do
        let(:endpoint) { 'VnpPersonWebServiceBean/VnpPersonService' }
        let(:action) { 'vnpPersonCreate' }
        let(:key) { 'return' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'VnpPersonWebServiceBean'
          expect(parsed_result['service']['path']).to eq 'VnpPersonService'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://personService.services.vonapp.vba.va.gov/'
        end
      end

      context 'VnpProcFormWebServiceBean' do
        let(:endpoint) { 'VnpProcFormWebServiceBean/VnpProcFormService' }
        let(:action) { 'vnpProcFormCreate' }
        let(:key) { 'return' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'VnpProcFormWebServiceBean'
          expect(parsed_result['service']['path']).to eq 'VnpProcFormService'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://procFormService.services.vonapp.vba.va.gov/'
        end
      end

      context 'VnpProcWebServiceBeanV2' do
        let(:endpoint) { 'VnpProcWebServiceBeanV2/VnpProcServiceV2' }
        let(:action) { 'vnpProcCreate' }
        let(:key) { 'return' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'VnpProcWebServiceBeanV2'
          expect(parsed_result['service']['path']).to eq 'VnpProcServiceV2'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://procService.services.v2.vonapp.vba.va.gov/'
        end
      end

      context 'VnpPtcpntAddrsWebServiceBean' do
        let(:endpoint) { 'VnpPtcpntAddrsWebServiceBean/VnpPtcpntAddrsService' }
        let(:action) { 'vnpPtcpntAddrsCreate' }
        let(:key) { 'return' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'VnpPtcpntAddrsWebServiceBean'
          expect(parsed_result['service']['path']).to eq 'VnpPtcpntAddrsService'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://ptcpntAddrsService.services.vonapp.vba.va.gov/'
        end
      end

      context 'VnpPtcpntPhoneWebServiceBean' do
        let(:endpoint) { 'VnpPtcpntPhoneWebServiceBean/VnpPtcpntPhoneService' }
        let(:action) { 'vnpPtcpntPhoneCreate' }
        let(:key) { 'return' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'VnpPtcpntPhoneWebServiceBean'
          expect(parsed_result['service']['path']).to eq 'VnpPtcpntPhoneService'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://ptcpntPhoneService.services.vonapp.vba.va.gov/'
        end
      end

      context 'VnpPtcpntWebServiceBean' do
        let(:endpoint) { 'VnpPtcpntWebServiceBean/VnpPtcpntService' }
        let(:action) { 'vnpPtcpntCreate' }
        let(:key) { 'return' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'VnpPtcpntWebServiceBean'
          expect(parsed_result['service']['path']).to eq 'VnpPtcpntService'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://ptcpntService.services.vonapp.vba.va.gov/'
        end
      end
    end
  end

  describe '#for_service' do
    context 'hardcoded WSDL' do
      before do
        Flipper.enable(:lighthouse_claims_api_hardcode_wsdl)
      end

      context 'Vdc' do
        let(:endpoint) { 'VDC/ManageRepresentativeService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VDC'
          expect(parsed_result['path']).to eq 'ManageRepresentativeService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://gov.va.vba.benefits.vdc/services'
        end
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

      context 'VnpPersonService' do
        let(:endpoint) { 'VnpPersonWebServiceBean/VnpPersonService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VnpPersonWebServiceBean'
          expect(parsed_result['path']).to eq 'VnpPersonService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://personService.services.vonapp.vba.va.gov/'
        end
      end

      context 'VnpProcFormWebServiceBean' do
        let(:endpoint) { 'VnpProcFormWebServiceBean/VnpProcFormService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VnpProcFormWebServiceBean'
          expect(parsed_result['path']).to eq 'VnpProcFormService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://procFormService.services.vonapp.vba.va.gov/'
        end
      end

      context 'VnpProcWebServiceBeanV2' do
        let(:endpoint) { 'VnpProcWebServiceBeanV2/VnpProcServiceV2' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VnpProcWebServiceBeanV2'
          expect(parsed_result['path']).to eq 'VnpProcServiceV2'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://procService.services.v2.vonapp.vba.va.gov/'
        end
      end

      context 'VnpPtcpntAddrsWebServiceBean' do
        let(:endpoint) { 'VnpPtcpntAddrsWebServiceBean/VnpPtcpntAddrsService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VnpPtcpntAddrsWebServiceBean'
          expect(parsed_result['path']).to eq 'VnpPtcpntAddrsService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://ptcpntAddrsService.services.vonapp.vba.va.gov/'
        end
      end

      context 'VnpPtcpntPhoneWebServiceBean' do
        let(:endpoint) { 'VnpPtcpntPhoneWebServiceBean/VnpPtcpntPhoneService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VnpPtcpntPhoneWebServiceBean'
          expect(parsed_result['path']).to eq 'VnpPtcpntPhoneService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://ptcpntPhoneService.services.vonapp.vba.va.gov/'
        end
      end

      context 'VnpPtcpntWebServiceBean' do
        let(:endpoint) { 'VnpPtcpntWebServiceBean/VnpPtcpntService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'VnpPtcpntWebServiceBean'
          expect(parsed_result['path']).to eq 'VnpPtcpntService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://ptcpntService.services.vonapp.vba.va.gov/'
        end
      end
    end
  end
end
