# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/find_definition'

describe ClaimsApi::FindDefinition do
  subject { described_class }

  describe '#for_service' do
    context 'hardcoded WSDL' do
      context 'TrackedItemService' do
        let(:endpoint) { 'TrackedItemService/TrackedItemService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'TrackedItemService'
          expect(parsed_result['path']).to eq 'TrackedItemService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://services.mapd.benefits.vba.va.gov/'
        end
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
