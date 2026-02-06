# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/providers/lighthouse/lighthouse_benefits_claims_provider'
require 'benefits_claims/responses/claim_response'
require 'support/benefits_claims/benefits_claims_provider'

RSpec.describe BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider do
  subject { provider }

  let(:current_user) { build(:user, :loa3, icn: '1234567890V123456') }
  let(:mock_service) { instance_double(BenefitsClaims::Service) }
  let(:mock_config) { instance_double(BenefitsClaims::Configuration) }

  # Shared comprehensive claim data structure
  let(:comprehensive_claim_attributes) do
    {
      'baseEndProductCode' => '400',
      'claimDate' => '2022-11-07',
      'claimPhaseDates' => {
        'phaseChangeDate' => '2022-11-07',
        'currentPhaseBack' => false,
        'phaseType' => 'COMPLETE',
        'latestPhaseType' => 'COMPLETE',
        'previousPhases' => {
          'phase1CompleteDate' => '2022-11-07'
        }
      },
      'claimType' => 'Compensation',
      'claimTypeCode' => '020NEW',
      'displayTitle' => 'compensation claim',
      'claimTypeBase' => 'claim_for_increase',
      'closeDate' => '2022-11-07',
      'decisionLetterSent' => true,
      'developmentLetterSent' => false,
      'documentsNeeded' => false,
      'endProductCode' => '020',
      'evidenceWaiverSubmitted5103' => false,
      'lighthouseId' => nil,
      'status' => 'COMPLETE',
      'supportingDocuments' => [
        {
          'documentId' => '{27832B64-2D88-4DEE-9F6F-DF80E4CAAA88}',
          'documentTypeLabel' => 'Military Personnel Record',
          'originalFileName' => 'dd214.pdf',
          'trackedItemId' => 123_456,
          'uploadDate' => '2022-11-01'
        }
      ],
      'evidenceSubmissions' => [],
      'contentions' => [
        {
          'name' => 'Tinnitus'
        }
      ],
      'events' => [
        {
          'date' => '2022-11-07',
          'type' => 'claim_received'
        }
      ],
      'issues' => [
        {
          'active' => true,
          'description' => 'Tinnitus',
          'diagnosticCode' => '6260',
          'lastAction' => 'granted',
          'date' => '2022-11-07'
        }
      ],
      'evidence' => [
        {
          'date' => '2022-11-01',
          'description' => 'DD214',
          'type' => 'Military Personnel Record'
        }
      ],
      'trackedItems' => [
        {
          'id' => 123_456,
          'displayName' => 'PMR Pending',
          'status' => 'NEEDED_FROM_YOU',
          'suspenseDate' => '2022-12-07',
          'type' => 'still_need_from_you_list',
          'closedDate' => nil,
          'description' => 'Please submit your private medical records',
          'overdue' => false,
          'receivedDate' => nil,
          'requestedDate' => '2022-11-01',
          'uploadsAllowed' => true,
          'uploaded' => false,
          'friendlyName' => 'Private Medical Records',
          'friendlyDescription' => 'We need your medical records from private providers',
          'canUploadFile' => true,
          'supportAliases' => ['PMR Request', 'General Records Request (Medical)'],
          'documents' => '[]',
          'date' => '2022-11-01'
        }
      ]
    }
  end

  let(:provider) { described_class.new(current_user) }

  # Shared examples for verifying comprehensive claim structure
  shared_examples 'preserves comprehensive claim structure' do
    it 'preserves all claim attributes through transformation' do
      attrs = claim_attributes

      # Verify basic attributes
      expect(attrs['baseEndProductCode']).to eq(comprehensive_claim_attributes['baseEndProductCode'])
      expect(attrs['claimDate']).to eq(comprehensive_claim_attributes['claimDate'])
      expect(attrs['claimType']).to eq(comprehensive_claim_attributes['claimType'])
      expect(attrs['displayTitle']).to eq(comprehensive_claim_attributes['displayTitle'])
      expect(attrs['claimTypeBase']).to eq(comprehensive_claim_attributes['claimTypeBase'])
      expect(attrs['status']).to eq(comprehensive_claim_attributes['status'])

      # Verify nested structures are preserved
      expect(attrs['claimPhaseDates']).to be_a(Hash)
      expect(attrs['claimPhaseDates']['phaseType']).to eq(
        comprehensive_claim_attributes['claimPhaseDates']['phaseType']
      )
      expect(attrs['claimPhaseDates']['currentPhaseBack']).to eq(
        comprehensive_claim_attributes['claimPhaseDates']['currentPhaseBack']
      )

      expect(attrs['supportingDocuments']).to be_an(Array)
      expect(attrs['supportingDocuments'].length).to eq(comprehensive_claim_attributes['supportingDocuments'].length)

      expect(attrs['contentions']).to be_an(Array)
      expect(attrs['contentions'].length).to eq(comprehensive_claim_attributes['contentions'].length)

      expect(attrs['events']).to be_an(Array)
      expect(attrs['events'].length).to eq(comprehensive_claim_attributes['events'].length)

      expect(attrs['issues']).to be_an(Array)
      expect(attrs['issues'].length).to eq(comprehensive_claim_attributes['issues'].length)

      expect(attrs['evidence']).to be_an(Array)
      expect(attrs['evidence'].length).to eq(comprehensive_claim_attributes['evidence'].length)

      expect(attrs['trackedItems']).to be_an(Array)
      expect(attrs['trackedItems'].length).to eq(comprehensive_claim_attributes['trackedItems'].length)

      # Verify tracked item fields are preserved
      tracked_item = attrs['trackedItems'].first
      expected_tracked_item = comprehensive_claim_attributes['trackedItems'].first
      expect(tracked_item['id']).to eq(expected_tracked_item['id'])
      expect(tracked_item['displayName']).to eq(expected_tracked_item['displayName'])
      expect(tracked_item['status']).to eq(expected_tracked_item['status'])
      expect(tracked_item['friendlyName']).to eq(expected_tracked_item['friendlyName'])
      expect(tracked_item['supportAliases']).to eq(expected_tracked_item['supportAliases'])
      expect(tracked_item['canUploadFile']).to eq(expected_tracked_item['canUploadFile'])
    end
  end

  before do
    allow(BenefitsClaims::Service).to receive(:new).with(current_user).and_return(mock_service)
    allow(mock_service).to receive(:config).and_return(mock_config)
    allow(mock_config).to receive(:base_api_path)
      .and_return("https://sandbox-api.va.gov/#{BenefitsClaims::Configuration::CLAIMS_PATH}")
  end

  # Validate interface contract compliance
  it_behaves_like 'benefits claims provider'

  describe '#initialize' do
    it 'initializes with a user and creates a service' do
      expect(BenefitsClaims::Service).to receive(:new).with(current_user)
      described_class.new(current_user)
    end
  end

  describe '#get_claims' do
    before do
      allow(mock_service).to receive(:get_claims).with(no_args).and_return(
        'data' => [
          { 'id' => '600342023', 'type' => 'claim', 'attributes' => comprehensive_claim_attributes },
          { 'id' => '600141237', 'type' => 'claim', 'attributes' => comprehensive_claim_attributes.slice(
            'baseEndProductCode', 'claimDate', 'claimType', 'status'
          ) }
        ]
      )
    end

    it 'retrieves claims from the Lighthouse service' do
      provider.get_claims
      expect(mock_service).to have_received(:get_claims).with(no_args)
    end

    describe 'claim data transformation' do
      let(:claim_attributes) { provider.get_claims['data'].first['attributes'] }

      include_examples 'preserves comprehensive claim structure'
    end

    it 'validates claims using the DTO' do
      expect(BenefitsClaims::Responses::ClaimResponse).to receive(:new).twice.and_call_original
      provider.get_claims
    end

    context 'when service raises a Faraday error' do
      let(:faraday_error) do
        Faraday::ServerError.new('error', { status: 500, body: { 'errors' => [{ 'detail' => 'Server error' }] } })
      end

      before do
        allow(mock_service).to receive(:get_claims).with(no_args).and_raise(faraday_error)
      end

      it 'handles the error using Lighthouse::ServiceException' do
        expect(Lighthouse::ServiceException).to receive(:send_error).with(
          faraday_error,
          'benefits_claims/providers/lighthouse/lighthouse_benefits_claims_provider',
          nil,
          anything
        ).and_call_original

        expect { provider.get_claims }.to raise_error(Common::Exceptions::ExternalServerInternalServerError)
      end
    end
  end

  describe '#get_claim' do
    let(:claim_id) { '600342023' }

    before do
      allow(mock_service).to receive(:get_claim).with(claim_id).and_return(
        'data' => { 'id' => claim_id, 'type' => 'claim', 'attributes' => comprehensive_claim_attributes }
      )
    end

    it 'retrieves a single claim from the Lighthouse service' do
      provider.get_claim(claim_id)
      expect(mock_service).to have_received(:get_claim).with(claim_id)
    end

    describe 'claim data transformation' do
      let(:claim_attributes) { provider.get_claim(claim_id)['data']['attributes'] }

      include_examples 'preserves comprehensive claim structure'
    end

    it 'validates the claim using the DTO' do
      expect(BenefitsClaims::Responses::ClaimResponse).to receive(:new).once.and_call_original
      provider.get_claim(claim_id)
    end

    context 'when service raises a Faraday error' do
      let(:faraday_error) do
        Faraday::ClientError.new('error', { status: 404, body: { 'errors' => [{ 'detail' => 'Not found' }] } })
      end

      before do
        allow(mock_service).to receive(:get_claim).with(claim_id).and_raise(faraday_error)
      end

      it 'handles the error using Lighthouse::ServiceException' do
        expect(Lighthouse::ServiceException).to receive(:send_error).with(
          faraday_error,
          'benefits_claims/providers/lighthouse/lighthouse_benefits_claims_provider',
          nil,
          anything
        ).and_call_original

        expect { provider.get_claim(claim_id) }.to raise_error(Common::Exceptions::ResourceNotFound)
      end
    end
  end
end
