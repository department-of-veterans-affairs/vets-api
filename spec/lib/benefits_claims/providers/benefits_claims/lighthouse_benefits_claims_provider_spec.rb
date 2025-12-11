# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/providers/benefits_claims/lighthouse_benefits_claims_provider'
require 'benefits_claims/responses/claim_response'

RSpec.describe BenefitsClaims::Providers::LighthouseBenefitsClaimsProvider do
  let(:current_user) { build(:user, :loa3, icn: '1234567890V123456') }
  let(:provider) { described_class.new(current_user) }
  let(:mock_service) { instance_double(BenefitsClaims::Service) }

  before do
    allow(BenefitsClaims::Service).to receive(:new).with(current_user.icn).and_return(mock_service)
  end

  describe '#initialize' do
    it 'initializes with a user and creates a service' do
      expect(BenefitsClaims::Service).to receive(:new).with(current_user.icn)
      described_class.new(current_user)
    end
  end

  describe '#get_claims' do
    let(:lighthouse_claims_response) do
      {
        'data' => [
          {
            'id' => '600342023',
            'type' => 'claim',
            'attributes' => {
              'baseEndProductCode' => '400',
              'claimDate' => '2022-11-07',
              'claimPhaseDates' => {
                'phaseChangeDate' => '2022-11-07',
                'phaseType' => 'COMPLETE'
              },
              'claimType' => 'Compensation',
              'claimTypeCode' => '020NEW',
              'closeDate' => '2022-11-07',
              'decisionLetterSent' => true,
              'developmentLetterSent' => false,
              'documentsNeeded' => false,
              'endProductCode' => '020',
              'evidenceWaiverSubmitted5103' => false,
              'lighthouseId' => nil,
              'status' => 'COMPLETE',
              'trackedItems' => [
                {
                  'displayName' => 'PMR Pending',
                  'status' => 'NEEDED_FROM_YOU'
                }
              ]
            }
          },
          {
            'id' => '600141237',
            'type' => 'claim',
            'attributes' => {
              'baseEndProductCode' => '400',
              'claimDate' => '2018-10-15',
              'claimPhaseDates' => {
                'phaseChangeDate' => '2018-10-15'
              },
              'claimType' => 'Compensation',
              'claimTypeCode' => '403',
              'closeDate' => '2018-10-15',
              'decisionLetterSent' => false,
              'developmentLetterSent' => false,
              'documentsNeeded' => false,
              'endProductCode' => '403',
              'evidenceWaiverSubmitted5103' => false,
              'status' => 'COMPLETE'
            }
          }
        ]
      }
    end

    before do
      allow(mock_service).to receive(:get_claims).and_return(lighthouse_claims_response)
    end

    it 'retrieves claims from the Lighthouse service' do
      provider.get_claims
      expect(mock_service).to have_received(:get_claims)
    end

    it 'preserves Lighthouse claim data structure' do
      result = provider.get_claims
      first_claim = result['data'].first

      expect(first_claim['id']).to eq('600342023')
      expect(first_claim['type']).to eq('claim')

      attrs = first_claim['attributes']
      expect(attrs['baseEndProductCode']).to eq('400')
      expect(attrs['claimDate']).to eq('2022-11-07')
      expect(attrs['claimPhaseDates']).to be_a(Hash)
      expect(attrs['claimPhaseDates']['phaseChangeDate']).to eq('2022-11-07')
      expect(attrs['claimPhaseDates']['phaseType']).to eq('COMPLETE')
      expect(attrs['claimType']).to eq('Compensation')
      expect(attrs['claimTypeCode']).to eq('020NEW')
      expect(attrs['closeDate']).to eq('2022-11-07')
      expect(attrs['decisionLetterSent']).to be(true)
      expect(attrs['developmentLetterSent']).to be(false)
      expect(attrs['documentsNeeded']).to be(false)
      expect(attrs['endProductCode']).to eq('020')
      expect(attrs['evidenceWaiverSubmitted5103']).to be(false)
      expect(attrs['lighthouseId']).to be_nil
      expect(attrs['status']).to eq('COMPLETE')
      expect(attrs['trackedItems']).to be_an(Array)
      expect(attrs['trackedItems'].length).to eq(1)
      expect(attrs['trackedItems'].first['displayName']).to eq('PMR Pending')
      expect(attrs['trackedItems'].first['status']).to eq('NEEDED_FROM_YOU')
    end

    it 'validates claims using the DTO' do
      expect(BenefitsClaims::Responses::ClaimResponse).to receive(:new).twice.and_call_original
      provider.get_claims
    end

    context 'when service raises an error' do
      before do
        allow(mock_service).to receive(:get_claims).and_raise(
          Common::Exceptions::ExternalServerInternalServerError
        )
      end

      it 'logs the error and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Lighthouse claims retrieval failed',
          hash_including(
            error_type: 'Common::Exceptions::ExternalServerInternalServerError',
            error_message: 'Internal server error'
          )
        )

        expect { provider.get_claims }.to raise_error(Common::Exceptions::ExternalServerInternalServerError)
      end
    end

  end

  describe '#get_claim' do
    let(:claim_id) { '600342023' }
    let(:lighthouse_claim_response) do
      {
        'data' => {
          'id' => claim_id,
          'type' => 'claim',
          'attributes' => {
            'baseEndProductCode' => '400',
            'claimDate' => '2022-11-07',
            'claimPhaseDates' => {
              'phaseChangeDate' => '2022-11-07',
              'phaseType' => 'COMPLETE'
            },
            'claimType' => 'Compensation',
            'claimTypeCode' => '020NEW',
            'closeDate' => '2022-11-07',
            'decisionLetterSent' => true,
            'developmentLetterSent' => false,
            'documentsNeeded' => false,
            'endProductCode' => '020',
            'evidenceWaiverSubmitted5103' => false,
            'lighthouseId' => nil,
            'status' => 'COMPLETE',
            'trackedItems' => [
              {
                'displayName' => 'PMR Pending',
                'status' => 'NEEDED_FROM_YOU'
              }
            ]
          }
        }
      }
    end

    before do
      allow(mock_service).to receive(:get_claim).with(claim_id).and_return(lighthouse_claim_response)
    end

    it 'retrieves a single claim from the Lighthouse service' do
      provider.get_claim(claim_id)
      expect(mock_service).to have_received(:get_claim).with(claim_id)
    end

    it 'preserves the single claim data structure' do
      result = provider.get_claim(claim_id)
      claim = result['data']

      expect(claim['id']).to eq(claim_id)
      expect(claim['type']).to eq('claim')

      attrs = claim['attributes']
      expect(attrs['baseEndProductCode']).to eq('400')
      expect(attrs['claimDate']).to eq('2022-11-07')
      expect(attrs['claimPhaseDates']).to be_a(Hash)
      expect(attrs['claimPhaseDates']['phaseChangeDate']).to eq('2022-11-07')
      expect(attrs['claimPhaseDates']['phaseType']).to eq('COMPLETE')
      expect(attrs['claimType']).to eq('Compensation')
      expect(attrs['claimTypeCode']).to eq('020NEW')
      expect(attrs['closeDate']).to eq('2022-11-07')
      expect(attrs['decisionLetterSent']).to be(true)
      expect(attrs['developmentLetterSent']).to be(false)
      expect(attrs['documentsNeeded']).to be(false)
      expect(attrs['endProductCode']).to eq('020')
      expect(attrs['evidenceWaiverSubmitted5103']).to be(false)
      expect(attrs['lighthouseId']).to be_nil
      expect(attrs['status']).to eq('COMPLETE')
      expect(attrs['trackedItems']).to be_an(Array)
      expect(attrs['trackedItems'].length).to eq(1)
      expect(attrs['trackedItems'].first['displayName']).to eq('PMR Pending')
      expect(attrs['trackedItems'].first['status']).to eq('NEEDED_FROM_YOU')
    end

    it 'validates the claim using the DTO' do
      expect(BenefitsClaims::Responses::ClaimResponse).to receive(:new).once.and_call_original
      provider.get_claim(claim_id)
    end

    context 'when service raises an error' do
      before do
        allow(mock_service).to receive(:get_claim).with(claim_id).and_raise(
          Common::Exceptions::ResourceNotFound
        )
      end

      it 'logs the error and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Lighthouse claim retrieval failed',
          hash_including(
            error_type: 'Common::Exceptions::ResourceNotFound',
            error_message: 'Resource not found'
          )
        )

        expect { provider.get_claim(claim_id) }.to raise_error(Common::Exceptions::ResourceNotFound)
      end
    end
  end
end
