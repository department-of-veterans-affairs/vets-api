# frozen_string_literal: true

require 'rails_helper'
require 'bgs_service/local_bgs_refactored/find_definition'

describe ClaimsApi::LocalBGSRefactored::FindDefinition do
  subject { described_class }

  let(:cached_services) { %w[ClaimantServiceBean/ClaimantWebService PersonWebServiceBean/PersonWebService].freeze }

  before do
    Flipper.disable(:lighthouse_claims_api_hardcode_wsdl)
  end

  describe '#for_action' do
    context 'hardcoded WSDL' do
      before do
        Flipper.enable(:lighthouse_claims_api_hardcode_wsdl)
      end

      context 'PersonWebServiceBean' do
        let(:endpoint) { 'PersonWebServiceBean/PersonWebService' }
        let(:action) { 'findPersonBySSN' }

        it 'response with the correct attributes' do
          result = subject.for_action(endpoint, action)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['service']['bean']['path']).to eq 'PersonWebServiceBean'
          expect(parsed_result['service']['path']).to eq 'PersonWebService'
          expect(parsed_result['service']['bean']['namespaces']['target']).to eq 'http://person.services.vetsnet.vba.va.gov/'
        end
      end
    end
  end

  describe '#for_service' do
    context 'hardcoded WSDL' do
      before do
        Flipper.enable(:lighthouse_claims_api_hardcode_wsdl)
      end

      context 'PersonWebService' do
        let(:endpoint) { 'PersonWebServiceBean/PersonWebService' }

        it 'response with the correct namespace' do
          result = subject.for_service(endpoint)
          parsed_result = JSON.parse(result.to_json)
          expect(parsed_result['bean']['path']).to eq 'PersonWebServiceBean'
          expect(parsed_result['path']).to eq 'PersonWebService'
          expect(parsed_result['bean']['namespaces']['target']).to eq 'http://person.services.vetsnet.vba.va.gov/'
        end
      end
    end
  end
end
