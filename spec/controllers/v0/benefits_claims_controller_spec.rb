# frozen_string_literal: true

require 'rails_helper'
require 'lighthouse/benefits_claims/constants'
require 'lighthouse/benefits_documents/documents_status_polling_service'
require 'lighthouse/benefits_documents/update_documents_status_service'

RSpec.describe V0::BenefitsClaimsController, type: :controller do
  let(:user) { create(:user, :loa3, :accountable, :legacy_icn) }
  let(:user_account) { create(:user_account, id: user.uuid) }
  let(:dependent_user) { build(:dependent_user_with_relationship, :loa3) }
  let(:claim_id) { 600_383_363 } # This is the claim in the vcr cassettes that we are using

  def expect_metric(endpoint, upload_status, expected_calls = 1)
    expected_tags = [
      'service:benefits-claims',
      'team:cross-benefits-crew',
      'team:benefits',
      'itportfolio:benefits-delivery',
      'dependency:lighthouse',
      "status:#{upload_status}"
    ]
    expect(StatsD).to have_received(:increment)
      .with("api.benefits_claims.#{endpoint}", expected_calls, tags: expected_tags)
  end

  before do
    user.user_account_uuid = user_account.id
    user.save!
    sign_in_as(user)

    token = 'fake_access_token'

    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
    allow(StatsD).to receive(:increment)
    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)

    # Allow Flipper calls to work normally, but stub our specific flag
    allow(Flipper).to receive(:enabled?).and_call_original
    allow(Flipper).to receive(:enabled?)
      .with(V0::BenefitsClaimsController::FEATURE_MULTI_CLAIM_PROVIDER, user)
      .and_return(true)

    # Mock provider registry to return Lighthouse provider by default for backward compatibility
    allow(BenefitsClaims::Providers::ProviderRegistry)
      .to receive(:enabled_provider_classes)
      .with(an_instance_of(User))
      .and_return([BenefitsClaims::Providers::Lighthouse::LighthouseBenefitsClaimsProvider])
  end

  describe '#index' do
    context 'when cst_multi_claim_provider is enabled with single provider' do
      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end

        expect(response).to have_http_status(:ok)
      end

      it 'adds a set of EVSSClaim records to the DB' do
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end

        expect(response).to have_http_status(:ok)
        # NOTE: There are 8 items in the VCR cassette, but some of them will
        # get filtered out by the service based on their 'status' values
        expect(EVSSClaim.all.count).to equal(6)
      end

      it 'returns claimType language modifications' do
        allow(Flipper).to receive(:enabled?).with(:cst_use_claim_title_generator_web).and_return(false)
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end
        parsed_body = JSON.parse(response.body)

        expect(parsed_body['data']
          .select { |claim| claim['attributes']['claimType'] == 'expenses related to death or burial' }.count).to eq 1
        expect(parsed_body['data']
          .select { |claim| claim['attributes']['claimType'] == 'Death' }.count).to eq 0
      end

      it 'adds correct displayTitle and claimTypeBase attributes to all claims' do
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end
        parsed_body = JSON.parse(response.body)
        claims = parsed_body['data']

        # All claims should have displayTitle and claimTypeBase attributes
        claims.each do |claim|
          expect(claim['attributes']).to have_key('displayTitle')
          expect(claim['attributes']).to have_key('claimTypeBase')
        end
      end

      it 'sets correct titles for Compensation claims' do
        allow(Flipper).to receive(:enabled?).with(:cst_use_claim_title_generator_web).and_return(true)
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end
        parsed_body = JSON.parse(response.body)
        compensation_claims = parsed_body['data'].select { |claim| claim['attributes']['claimType'] == 'Compensation' }

        compensation_claims.each do |claim|
          expect(claim['attributes']['displayTitle']).to eq('Claim for compensation')
          expect(claim['attributes']['claimTypeBase']).to eq('compensation claim')
        end

        expect(compensation_claims.count).to be > 0
      end

      it 'sets correct titles for Death claims using special case transformation' do
        allow(Flipper).to receive(:enabled?).with(:cst_use_claim_title_generator_web).and_return(false)
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end
        parsed_body = JSON.parse(response.body)
        death_claims = parsed_body['data'].select do |claim|
          claim['attributes']['claimType'] == 'expenses related to death or burial'
        end

        expect(death_claims.count).to eq(1)
      end

      it 'sets correct display title and claim type base for Death claims using title generator' do
        allow(Flipper).to receive(:enabled?).with(:cst_use_claim_title_generator_web).and_return(true)
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end
        parsed_body = JSON.parse(response.body)
        death_claims = parsed_body['data'].select do |claim|
          claim['attributes']['claimType'] == 'expenses related to death or burial'
        end

        expect(death_claims.count).to eq(1)
        death_claim = death_claims.first

        expect(death_claim['attributes']['displayTitle']).to eq('Claim for expenses related to death or burial')
        expect(death_claim['attributes']['claimTypeBase']).to eq('expenses related to death or burial claim')
      end

      it 'sets correct titles for claims with claimTypeCode but null claimType' do
        # rubocop:disable Naming/VariableNumber
        allow(Flipper).to receive(:enabled?).with(:cst_filter_ep_960).and_return false
        allow(Flipper).to receive(:enabled?).with(:cst_filter_ep_290).and_return false
        # rubocop:enable Naming/VariableNumber
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end
        parsed_body = JSON.parse(response.body)
        code_only_claims = parsed_body['data'].select do |claim|
          claim['attributes']['claimType'].nil? &&
            !claim['attributes']['claimTypeCode'].nil?
        end

        expect(code_only_claims.count).to eq(2)

        # Check that both claims with claimTypeCode get default titles (since these codes aren't in our mapping)
        code_only_claims.each do |claim|
          expect(claim['attributes']['displayTitle']).to eq('Claim for disability compensation')
          expect(claim['attributes']['claimTypeBase']).to eq('disability compensation claim')
        end
      end

      it 'handles claims with specific pension and dependency codes correctly' do
        # Create a mock claim with dependency code to verify the TitleGenerator mapping
        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claims).and_return(
          {
            'data' => [
              {
                'id' => '123456',
                'type' => 'claim',
                'attributes' => {
                  'claimDate' => '2024-01-01',
                  'claimType' => nil,
                  'claimTypeCode' => '130DPNDCY', # This is a dependency code
                  'status' => 'CLAIM_RECEIVED'
                }
              },
              {
                'id' => '123457',
                'type' => 'claim',
                'attributes' => {
                  'claimDate' => '2024-01-01',
                  'claimType' => nil,
                  'claimTypeCode' => '180AILP', # This is a veterans pension code
                  'status' => 'CLAIM_RECEIVED'
                }
              }
            ]
          }
        )

        get(:index)
        parsed_body = JSON.parse(response.body)
        claims = parsed_body['data']

        dependency_claim = claims.find { |claim| claim['attributes']['claimTypeCode'] == '130DPNDCY' }
        pension_claim = claims.find { |claim| claim['attributes']['claimTypeCode'] == '180AILP' }

        # Dependency claim should get dependency title
        expect(dependency_claim['attributes']['displayTitle']).to eq('Request to add or remove a dependent')
        expect(dependency_claim['attributes']['claimTypeBase']).to eq('request to add or remove a dependent')

        # Veterans pension claim should get veterans pension title
        expect(pension_claim['attributes']['displayTitle']).to eq('Claim for Veterans Pension')
        expect(pension_claim['attributes']['claimTypeBase']).to eq('Veterans Pension claim')
      end

      it 'handles claims with disability compensation codes correctly' do
        # Create mock claims with disability compensation codes to verify the TitleGenerator mapping
        allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claims).and_return(
          {
            'data' => [
              {
                'id' => '123458',
                'type' => 'claim',
                'attributes' => {
                  'claimDate' => '2024-01-01',
                  'claimType' => 'Compensation',
                  'claimTypeCode' => '020NEW', # Disability compensation code
                  'status' => 'CLAIM_RECEIVED'
                }
              },
              {
                'id' => '123459',
                'type' => 'claim',
                'attributes' => {
                  'claimDate' => '2024-01-01',
                  'claimType' => nil,
                  'claimTypeCode' => '110LCOMP7', # Disability compensation code
                  'status' => 'CLAIM_RECEIVED'
                }
              },
              {
                'id' => '123460',
                'type' => 'claim',
                'attributes' => {
                  'claimDate' => '2024-01-01',
                  'claimType' => 'Compensation',
                  'claimTypeCode' => '010LCOMPBDD', # Disability compensation code
                  'status' => 'CLAIM_RECEIVED'
                }
              }
            ]
          }
        )

        get(:index)
        parsed_body = JSON.parse(response.body)
        claims = parsed_body['data']

        # All three claims should get disability compensation title
        claims.each do |claim|
          expect(claim['attributes']['displayTitle']).to eq('Claim for disability compensation')
          expect(claim['attributes']['claimTypeBase']).to eq('disability compensation claim')
        end

        # Verify we have all three claims
        expect(claims.length).to eq(3)
        expect(claims.map do |c|
          c['attributes']['claimTypeCode']
        end).to contain_exactly('020NEW', '110LCOMP7', '010LCOMPBDD')
      end

      context 'disability compensation claim titles with flipper flag' do
        let(:mock_disability_claim) do
          {
            'data' => [
              {
                'id' => '123461',
                'type' => 'claim',
                'attributes' => {
                  'claimDate' => '2024-01-01',
                  'claimType' => 'Compensation',
                  'claimTypeCode' => '020SUPP', # Disability compensation code
                  'status' => 'CLAIM_RECEIVED'
                }
              }
            ]
          }
        end

        it 'sets correct disability compensation titles when flag is enabled' do
          allow(Flipper).to receive(:enabled?).with(:cst_use_claim_title_generator_web).and_return(true)
          allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claims).and_return(mock_disability_claim)

          get(:index)
          parsed_body = JSON.parse(response.body)
          claim = parsed_body['data'].first

          # With flag enabled, claimType should remain as-is
          expect(claim['attributes']['claimType']).to eq('Compensation')
          # But displayTitle and claimTypeBase should be set to disability compensation
          expect(claim['attributes']['displayTitle']).to eq('Claim for disability compensation')
          expect(claim['attributes']['claimTypeBase']).to eq('disability compensation claim')
        end

        it 'does not set displayTitle and claimTypeBase when flag is disabled' do
          allow(Flipper).to receive(:enabled?).with(:cst_use_claim_title_generator_web).and_return(false)
          allow_any_instance_of(BenefitsClaims::Service).to receive(:get_claims).and_return(mock_disability_claim)

          get(:index)
          parsed_body = JSON.parse(response.body)
          claim = parsed_body['data'].first

          # When flag is disabled, the title generator is not invoked
          # so displayTitle and claimTypeBase should not be present
          expect(claim['attributes']['displayTitle']).to be_nil
          expect(claim['attributes']['claimTypeBase']).to be_nil
          # claimType should remain unchanged
          expect(claim['attributes']['claimType']).to eq('Compensation')
        end
      end

      context 'when :cst_show_document_upload_status is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(
            :cst_show_document_upload_status,
            instance_of(User)
          ).and_return(true)
        end

        context 'when multiple records with different upload statuses are returned' do
          before do
            create(:bd_evidence_submission_created, claim_id:)
            create(:bd_evidence_submission_queued, claim_id:)
            create(:bd_evidence_submission_pending, claim_id:)
            create(:bd_lh_evidence_submission_failed_type1_error, claim_id:)
            create(:bd_lh_evidence_submission_failed_type2_error, claim_id:)
            create(:bd_lh_evidence_submission_success, claim_id:)
            create(:bd_lh_evidence_submission_success, claim_id:)
          end

          it 'increments the metric for each status' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end
            expect_metric('index', 'CREATED', 1)
            expect_metric('index', 'QUEUED', 1)
            expect_metric('index', 'IN_PROGRESS', 1)
            expect_metric('index', 'FAILED', 2)
            expect_metric('index', 'SUCCESS', 2)
          end
        end

        context 'when evidence submission metrics reporting fails' do
          before do
            # Allow normal EvidenceSubmission calls to work
            allow(EvidenceSubmission).to receive(:where).and_call_original

            # Mock specifically for the metrics method pattern (claim_id with an array)
            allow(EvidenceSubmission).to receive(:where).with(claim_id: kind_of(Array))
                                                        .and_raise(StandardError, 'Database connection error')
          end

          it 'logs the error and continues processing' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end

            expect(response).to have_http_status(:ok)
            expect(Rails.logger).to have_received(:error)
              .with('BenefitsClaimsController#index Error fetching evidence submissions', hash_including(
                                                                                            :error_message, :claim_ids
                                                                                          ))
          end
        end

        context 'when adding evidence submissions fails' do
          before do
            create(:bd_lh_evidence_submission_success, claim_id:)
            allow_any_instance_of(V0::BenefitsClaimsController).to receive(:add_evidence_submissions)
              .and_raise(StandardError, 'Error processing evidence')
          end

          it 'logs the error with endpoint and claim_ids and continues processing' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end

            expect(response).to have_http_status(:ok)
            expect(Rails.logger).to have_received(:error)
              .with('BenefitsClaimsController#index Error adding evidence submissions', hash_including(:claim_ids))
          end
        end

        context 'when including evidenceSubmissions in response' do
          let(:tracked_item_id) { 394_443 }
          let(:unique_file_name1) { 'test_unique_document_1.pdf' }
          let(:unique_file_name2) { 'test_unique_document_2.pdf' }

          before do
            create(:bd_lh_evidence_submission_success,
                   claim_id:,
                   tracked_item_id:,
                   template_metadata: {
                     personalisation: {
                       file_name: unique_file_name1,
                       document_type: 'Medical Record'
                     }
                   }.to_json)
            create(:bd_lh_evidence_submission_failed_type2_error,
                   claim_id:,
                   template_metadata: {
                     personalisation: {
                       file_name: unique_file_name2,
                       document_type: 'Birth Certificate'
                     }
                   }.to_json)
          end

          it 'includes evidenceSubmissions in each claim' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end

            expect(response).to have_http_status(:ok)
            parsed_body = JSON.parse(response.body)

            test_claim = parsed_body['data'].find { |claim| claim['id'] == claim_id.to_s }
            expect(test_claim).not_to be_nil

            evidence_submissions = test_claim.dig('attributes', 'evidenceSubmissions')
            expect(evidence_submissions).to be_present
            expect(evidence_submissions.size).to eq(2)
          end

          it 'filters duplicate evidence submissions' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end

            expect(response).to have_http_status(:ok)
            parsed_body = JSON.parse(response.body)

            parsed_body['data'].each do |claim|
              expect(claim['attributes']).to have_key('evidenceSubmissions')
              expect(claim['attributes']['evidenceSubmissions']).to be_an(Array)
            end
          end
        end

        context 'when no evidence submissions exist for claims' do
          it 'returns empty evidenceSubmissions array' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end

            expect(response).to have_http_status(:ok)
            parsed_body = JSON.parse(response.body)

            parsed_body['data'].each do |claim|
              expect(claim['attributes']).to have_key('evidenceSubmissions')
              expect(claim['attributes']['evidenceSubmissions']).to be_an(Array)
            end
          end
        end

        context 'when multiple claims have different evidence submissions' do
          let(:second_claim_id) { 600_229_972 }
          let(:tracked_item_id) { 394_443 }
          let(:unique_file_name1) { 'claim1_document_1.pdf' }
          let(:unique_file_name2) { 'claim1_document_2.pdf' }
          let(:unique_file_name3) { 'claim2_document_1.pdf' }

          before do
            create(:bd_lh_evidence_submission_success,
                   claim_id:,
                   tracked_item_id:,
                   template_metadata: {
                     personalisation: {
                       file_name: unique_file_name1,
                       document_type: 'Medical Record'
                     }
                   }.to_json)
            create(:bd_lh_evidence_submission_failed_type2_error,
                   claim_id:,
                   template_metadata: {
                     personalisation: {
                       file_name: unique_file_name2,
                       document_type: 'Birth Certificate'
                     }
                   }.to_json)
            create(:bd_evidence_submission_pending,
                   claim_id: second_claim_id,
                   template_metadata: {
                     personalisation: {
                       file_name: unique_file_name3,
                       document_type: 'DD214'
                     }
                   }.to_json)
          end

          it 'correctly associates evidence submissions with their respective claims' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end

            expect(response).to have_http_status(:ok)
            parsed_body = JSON.parse(response.body)

            first_claim = parsed_body['data'].find { |c| c['id'] == claim_id.to_s }
            first_claim_submissions = first_claim.dig('attributes', 'evidenceSubmissions')
            expect(first_claim_submissions).to be_present
            expect(first_claim_submissions.size).to eq(2)
            expect(first_claim_submissions.all? { |es| es['claim_id'] == claim_id }).to be true

            second_claim = parsed_body['data'].find { |c| c['id'] == second_claim_id.to_s }
            second_claim_submissions = second_claim.dig('attributes', 'evidenceSubmissions')
            expect(second_claim_submissions).to be_present
            expect(second_claim_submissions.size).to eq(1)
            expect(second_claim_submissions.first['claim_id']).to eq(second_claim_id)
          end
        end
      end

      context 'when :cst_show_document_upload_status is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(
            :cst_show_document_upload_status,
            instance_of(User)
          ).and_return(false)

          # Create some evidence submissions that should NOT be included
          create(:bd_lh_evidence_submission_success, claim_id:)
          create(:bd_lh_evidence_submission_failed_type2_error, claim_id:)
        end

        it 'does not include evidenceSubmissions in claims' do
          VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
            get(:index)
          end

          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)

          # Find the claim with our test claim_id
          test_claim = parsed_body['data'].find { |claim| claim['id'] == claim_id.to_s }

          expect(test_claim.dig('attributes', 'evidenceSubmissions')).to be_nil
        end
      end
    end

    context 'it updates existing EVSSClaim records when visited' do
      let(:evss_id) { 600_383_363 }
      let(:claim) { create(:evss_claim, evss_id:, user_uuid: user.uuid) }
      let(:t1) { claim.updated_at }

      before do
        p "TIMESTAMP #1: #{t1} #{t1.class}"
      end

      it 'updates the ’updated_at’ field on existing EVSSClaim records' do
        Timecop.travel(10.minutes.from_now)

        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end

        expect(response).to have_http_status(:ok)

        t2 = EVSSClaim.where(evss_id:).first.updated_at
        expect(t2).to be > t1
      end
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        VCR.use_cassette('lighthouse/benefits_claims/index/401_response') do
          get(:index)
        end

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when cst_multi_claim_provider is enabled with multiple providers' do
      let(:mock_provider_class_one) do
        Class.new do
          def self.name
            'MockProviderOne'
          end

          def initialize(user)
            @user = user
          end

          def get_claims
            {
              'data' => [
                {
                  'id' => 'provider_one_claim_one',
                  'type' => 'claim',
                  'attributes' => { 'claimType' => 'Compensation', 'status' => 'CLAIM_RECEIVED' }
                }
              ]
            }
          end
        end
      end

      let(:mock_provider_class_two) do
        Class.new do
          def self.name
            'MockProviderTwo'
          end

          def initialize(user)
            @user = user
          end

          def get_claims
            {
              'data' => [
                {
                  'id' => 'provider_two_claim_one',
                  'type' => 'claim',
                  'attributes' => { 'claimType' => 'Compensation', 'status' => 'CLAIM_RECEIVED' }
                }
              ]
            }
          end
        end
      end

      before do
        allow(BenefitsClaims::Providers::ProviderRegistry)
          .to receive(:enabled_provider_classes)
          .with(an_instance_of(User))
          .and_return([mock_provider_class_one, mock_provider_class_two])
      end

      it 'aggregates claims from multiple providers' do
        get(:index)
        parsed_body = JSON.parse(response.body)

        expect(response).to have_http_status(:ok)
        expect(parsed_body['data'].count).to eq(2)
        expect(parsed_body['data'].map { |claim| claim['id'] })
          .to contain_exactly('provider_one_claim_one', 'provider_two_claim_one')
      end

      it 'continues processing when one provider fails' do
        failing_provider = Class.new do
          def self.name
            'FailingProvider'
          end

          def initialize(user)
            @user = user
          end

          def get_claims
            raise StandardError, 'Provider failed'
          end
        end

        allow(BenefitsClaims::Providers::ProviderRegistry)
          .to receive(:enabled_provider_classes)
          .with(an_instance_of(User))
          .and_return([mock_provider_class_one, failing_provider])

        get(:index)
        parsed_body = JSON.parse(response.body)

        expect(response).to have_http_status(:ok)
        expect(parsed_body['data'].count).to eq(1)
        expect(parsed_body['data'].first['id']).to eq('provider_one_claim_one')
        expect(parsed_body['meta']['provider_errors']).to be_present
        expect(parsed_body['meta']['provider_errors'].first['provider']).to eq('FailingProvider')
        expect(parsed_body['meta']['provider_errors'].first['error']).to eq('Provider temporarily unavailable')
      end

      it 'logs errors and increments StatsD when provider fails' do
        failing_provider = Class.new do
          def self.name
            'FailingProvider'
          end

          def initialize(_user)
            raise StandardError, 'Provider initialization failed'
          end
        end

        allow(BenefitsClaims::Providers::ProviderRegistry)
          .to receive(:enabled_provider_classes)
          .with(an_instance_of(User))
          .and_return([failing_provider, mock_provider_class_one])

        expect(Rails.logger).to receive(:warn).with(
          'Provider FailingProvider failed',
          hash_including(provider: 'FailingProvider', error_class: 'StandardError')
        )
        expect(StatsD).to receive(:increment).with(
          'api.benefits_claims.provider_error',
          hash_including(tags: array_including('provider:FailingProvider'))
        )

        get(:index)
      end

      it 'returns empty data when multiple providers fail' do
        failing_provider_one = Class.new do
          def self.name
            'FailingProviderOne'
          end

          def initialize(_user)
            raise StandardError, 'Provider 1 failed'
          end
        end

        failing_provider_two = Class.new do
          def self.name
            'FailingProviderTwo'
          end

          def initialize(_user)
            raise StandardError, 'Provider 2 failed'
          end
        end

        allow(BenefitsClaims::Providers::ProviderRegistry)
          .to receive(:enabled_provider_classes)
          .with(an_instance_of(User))
          .and_return([failing_provider_one, failing_provider_two])

        get(:index)
        parsed_body = JSON.parse(response.body)

        expect(response).to have_http_status(:ok)
        expect(parsed_body['data']).to be_empty
        expect(parsed_body['meta']['provider_errors']).to be_present
        expect(parsed_body['meta']['provider_errors'].count).to eq(2)
        expect(parsed_body['meta']['provider_errors'].map { |e| e['provider'] })
          .to contain_exactly('FailingProviderOne', 'FailingProviderTwo')
      end

      context 'with provider-level exceptions (graceful degradation)' do
        it 'continues when first provider throws GatewayTimeout' do
          timeout_provider = Class.new do
            def self.name
              'TimeoutProvider'
            end

            def initialize(_user); end

            def get_claims
              raise Common::Exceptions::GatewayTimeout
            end
          end

          allow(BenefitsClaims::Providers::ProviderRegistry)
            .to receive(:enabled_provider_classes)
            .with(an_instance_of(User))
            .and_return([timeout_provider, mock_provider_class_one])

          get(:index)
          parsed_body = JSON.parse(response.body)

          expect(response).to have_http_status(:ok)
          expect(parsed_body['data'].count).to eq(1)
          expect(parsed_body['data'].first['id']).to eq('provider_one_claim_one')
          expect(parsed_body['meta']['provider_errors']).to be_present
          expect(parsed_body['meta']['provider_errors'].first['provider']).to eq('TimeoutProvider')
        end

        it 'continues when first provider throws ServiceUnavailable' do
          unavailable_provider = Class.new do
            def self.name
              'UnavailableProvider'
            end

            def initialize(_user); end

            def get_claims
              raise Common::Exceptions::ServiceUnavailable
            end
          end

          allow(BenefitsClaims::Providers::ProviderRegistry)
            .to receive(:enabled_provider_classes)
            .with(an_instance_of(User))
            .and_return([unavailable_provider, mock_provider_class_one])

          get(:index)
          parsed_body = JSON.parse(response.body)

          expect(response).to have_http_status(:ok)
          expect(parsed_body['data'].count).to eq(1)
          expect(parsed_body['data'].first['id']).to eq('provider_one_claim_one')
          expect(parsed_body['meta']['provider_errors']).to be_present
          expect(parsed_body['meta']['provider_errors'].first['provider']).to eq('UnavailableProvider')
        end

        it 'continues when first provider throws ResourceNotFound' do
          not_found_provider = Class.new do
            def self.name
              'NotFoundProvider'
            end

            def initialize(_user); end

            def get_claims
              raise Common::Exceptions::ResourceNotFound
            end
          end

          allow(BenefitsClaims::Providers::ProviderRegistry)
            .to receive(:enabled_provider_classes)
            .with(an_instance_of(User))
            .and_return([not_found_provider, mock_provider_class_one])

          get(:index)
          parsed_body = JSON.parse(response.body)

          expect(response).to have_http_status(:ok)
          expect(parsed_body['data'].count).to eq(1)
          expect(parsed_body['data'].first['id']).to eq('provider_one_claim_one')
          expect(parsed_body['meta']['provider_errors']).to be_present
          expect(parsed_body['meta']['provider_errors'].first['provider']).to eq('NotFoundProvider')
        end
      end

      context 'with user-level exceptions (critical errors)' do
        it 're-raises Unauthorized and stops processing' do
          unauthorized_provider = Class.new do
            def self.name
              'UnauthorizedProvider'
            end

            def initialize(_user); end

            def get_claims
              raise Common::Exceptions::Unauthorized
            end
          end

          allow(BenefitsClaims::Providers::ProviderRegistry)
            .to receive(:enabled_provider_classes)
            .with(an_instance_of(User))
            .and_return([unauthorized_provider, mock_provider_class_one])

          get(:index)

          # HTTP status proves exception was re-raised and stopped processing
          expect(response).to have_http_status(:unauthorized)
        end

        it 're-raises Forbidden and stops processing' do
          forbidden_provider = Class.new do
            def self.name
              'ForbiddenProvider'
            end

            def initialize(_user); end

            def get_claims
              raise Common::Exceptions::Forbidden
            end
          end

          allow(BenefitsClaims::Providers::ProviderRegistry)
            .to receive(:enabled_provider_classes)
            .with(an_instance_of(User))
            .and_return([forbidden_provider, mock_provider_class_one])

          get(:index)

          # HTTP status proves exception was re-raised and stopped processing
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end

  describe '#show' do
    context 'when cst_multi_claim_provider is enabled with single provider' do
      before do
        allow(Flipper).to receive(:enabled?).and_call_original
      end

      it 'modifies the claim data to include additional, human-readable fields' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
          get(:show, params: { id: '600383363' })
        end
        tracked_items = JSON.parse(response.body)['data']['attributes']['trackedItems']
        can_upload_values = tracked_items.map { |i| i['canUploadFile'] }
        expect(can_upload_values).to eq([true, true, false, true, true, true, true, true, false,
                                         true, true, true, false, false, true])
        friendly_name_values = tracked_items.map { |i| i['friendlyName'] }
        expect(friendly_name_values).to include('Authorization to disclose information')
        expect(friendly_name_values).to include('Proof of service')
        expect(friendly_name_values).to include('Employment information')
        expect(friendly_name_values).to include('Direct deposit information')
        expect(friendly_name_values).to include('Details about cause of PTSD')
        expect(friendly_name_values).to include('Reserve records')
        expect(friendly_name_values).to include('Non-VA medical records')
        expect(friendly_name_values).to include('Disability exam for hearing')
        expect(friendly_name_values).to include('Mental health exam')
        activity_description_values = tracked_items.map { |i| i['activityDescription'] }
        expect(activity_description_values).to include('We need your permission to request your personal' \
                                                       ' information from a non-VA source, like a private' \
                                                       ' doctor or hospital.')
        expect(activity_description_values).to include('We need employment information from your most' \
                                                       ' recent employer.')
        expect(activity_description_values).to include('We need your direct deposit information in' \
                                                       ' order to pay benefits, if awarded.')
        expect(activity_description_values).to include('We need information about the cause of' \
                                                       ' your posttraumatic stress disorder (PTSD).')
        expect(activity_description_values).to include('We’ve requested your reserve records on' \
                                                       ' your behalf. No action is needed.')
        expect(activity_description_values).to include('We’ve requested your proof of service on' \
                                                       ' your behalf. No action is needed.')
        expect(activity_description_values).to include('We’ve requested your non-VA medical records on' \
                                                       ' your behalf. No action is needed.')
        short_description_values = tracked_items.map { |i| i['shortDescription'] }
        expect(short_description_values).to include('We’ve requested your service' \
                                                    ' records or treatment records from your reserve unit.')
        expect(short_description_values).to include('We’ve requested all your' \
                                                    ' DD Form 214’s or other separation papers for all' \
                                                    ' your periods of military service.')
        support_alias_values = tracked_items.map { |i| i['supportAliases'] }
        expect(support_alias_values).to include(['21-4142/21-4142a'])
        expect(support_alias_values).to include(['VA Form 21-4192'])
        expect(support_alias_values).to include(['EFT - Treasure Mandate Notification'])
        expect(support_alias_values).to include(['VA Form 21-0781', 'PTSD - Need stressor details'])
        expect(support_alias_values).to include(['RV1 - Reserve Records Request'])
        expect(support_alias_values).to include(['Proof of Service (DD214, etc.)'])
        expect(support_alias_values).to include(['PMR Request', 'General Records Request (Medical)'])
        expect(support_alias_values).to include(['General Records Request (Medical)', 'PMR Request'])
        expect(support_alias_values).to include(['DBQ AUDIO Hearing Loss and Tinnitus'])
        expect(support_alias_values).to include(['DBQ PSYCH Mental Disorders'])
      end

      it 'overrides the tracked item status to NEEDED_FROM_OTHERS' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
          get(:show, params: { id: '600383363' })
        end
        parsed_body = JSON.parse(response.body)
        expect(parsed_body.dig('data', 'attributes', 'trackedItems', 4,
                               'displayName')).to eq('RV1 - Reserve Records Request')
        # In the cassette, this value is NEEDED_FROM_YOU
        expect(parsed_body.dig('data', 'attributes', 'trackedItems', 4, 'status')).to eq('NEEDED_FROM_OTHERS')
      end

      context 'when :cst_suppress_evidence_requests_website is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(true)
        end

        it 'excludes suppressed evidence request tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          names = parsed_body.dig('data', 'attributes', 'trackedItems').map { |i| i['displayName'] }
          expect(names & BenefitsClaims::Constants::SUPPRESSED_EVIDENCE_REQUESTS).to be_empty
        end
      end

      context 'when :cst_suppress_evidence_requests_website is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(false)
        end

        it 'includes suppressed evidence request tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          names = parsed_body.dig('data', 'attributes', 'trackedItems').map { |i| i['displayName'] }
          expect(names & BenefitsClaims::Constants::SUPPRESSED_EVIDENCE_REQUESTS).not_to be_empty
        end
      end

      context "when 'cst_evidence_requests_content_override' is disabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_evidence_requests_content_override, anything).and_return(false)
        end

        it 'returns tracked items with legacy content fields only' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end

          parsed_body = JSON.parse(response.body)
          tracked_items = parsed_body.dig('data', 'attributes', 'trackedItems')
          form_item = tracked_items.find { |i| i['displayName'] == '21-4142/21-4142a' }
          # Legacy fields should be populated
          expect(form_item['friendlyName']).to eq('Authorization to disclose information')
          expect(form_item['canUploadFile']).to be true
          expect(form_item['supportAliases']).to eq(['21-4142/21-4142a'])
          # New content override fields should NOT be present
          expect(form_item).not_to have_key('longDescription')
          expect(form_item).not_to have_key('nextSteps')
          expect(form_item).not_to have_key('noActionNeeded')
          expect(form_item).not_to have_key('isDBQ')
          expect(form_item).not_to have_key('isProperNoun')
          expect(form_item).not_to have_key('isSensitive')
          expect(form_item).not_to have_key('noProvidePrefix')
        end
      end

      context "when 'cst_evidence_requests_content_override' is enabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_evidence_requests_content_override, anything).and_return(true)
        end

        it 'returns tracked items with new content override fields as well as legacy fields' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end

          parsed_body = JSON.parse(response.body)
          tracked_items = parsed_body.dig('data', 'attributes', 'trackedItems')
          form_item = tracked_items.find { |i| i['displayName'] == '21-4142/21-4142a' }
          # Existing fields should still be populated
          expect(form_item['friendlyName']).to eq('Authorization to disclose information')
          expect(form_item['canUploadFile']).to be true
          expect(form_item['supportAliases']).to eq(['21-4142/21-4142a'])
          # New structured content fields should be present
          expect(form_item['longDescription']).to be_a(Hash)
          expect(form_item['longDescription']).to have_key('blocks')
          expect(form_item['nextSteps']).to be_a(Hash)
          expect(form_item['nextSteps']).to have_key('blocks')
          # New boolean flags should be present
          expect(form_item).to have_key('noActionNeeded')
          expect(form_item).to have_key('isDBQ')
          expect(form_item).to have_key('isProperNoun')
          expect(form_item).to have_key('isSensitive')
          expect(form_item).to have_key('noProvidePrefix')
        end

        context 'when a tracked item does not have content overrides' do
          let(:test_display_name) { 'Submit buddy statement(s)' }

          before do
            # First allow all calls to pass through to the real implementation
            allow(BenefitsClaims::TrackedItemContent).to receive(:find_by_display_name).and_call_original
            # Then override for this specific display name to simulate no content overrides
            allow(BenefitsClaims::TrackedItemContent).to receive(:find_by_display_name)
              .with(test_display_name).and_return(nil)
          end

          it 'falls back to legacy content fields only' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: '600383363' })
            end

            parsed_body = JSON.parse(response.body)
            tracked_items = parsed_body.dig('data', 'attributes', 'trackedItems')
            buddy_statement_item = tracked_items.find { |i| i['displayName'] == test_display_name }
            # Should fall back to legacy content fields
            expect(buddy_statement_item['friendlyName']).to eq('Witness or corroboration statements')
            expect(buddy_statement_item['canUploadFile']).to be true
            expect(buddy_statement_item['supportAliases']).to eq(['Submit buddy statement(s)'])
            # New content override fields should NOT be present for items without overrides
            expect(buddy_statement_item).not_to have_key('longDescription')
            expect(buddy_statement_item).not_to have_key('nextSteps')
          end
        end
      end

      context 'when :cst_show_document_upload_status is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(
            :cst_show_document_upload_status,
            instance_of(User)
          ).and_return(false)
        end

        it 'doesnt show the evidenceSubmissions section in claim attributes' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'attributes', 'evidenceSubmissions')).to be_nil
        end
      end

      context 'when :cst_show_document_upload_status is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(
            :cst_show_document_upload_status,
            instance_of(User)
          ).and_return(true)
        end

        context 'when record does not have a tracked item' do
          before do
            create(:bd_lh_evidence_submission_success, claim_id:)
          end

          it 'shows the evidenceSubmissions section in claim attributes' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end
            parsed_body = JSON.parse(response.body)
            evidence_submissions = parsed_body.dig('data', 'attributes', 'evidenceSubmissions')

            expect(evidence_submissions.size).to eq(1)

            submission = evidence_submissions[0]

            expect(submission['claim_id']).to eq(claim_id)
            expect(submission['document_type']).to eq('Birth Certificate')
            expect(submission['file_name']).to eq('testfile.txt')
            expect(submission['upload_status']).to eq('SUCCESS')
            expect(submission['lighthouse_upload']).to be(false)
            expect(submission['tracked_item_id']).to be_nil # because no tracked item
            expect(submission['tracked_item_display_name']).to be_nil # because no tracked item
            expect(submission['tracked_item_friendly_name']).to be_nil # because no tracked item
            expect(submission['acknowledgement_date']).to be_nil
            expect(submission['failed_date']).to be_nil
            expect(submission['id']).to be_present

            expect_metric('show', 'SUCCESS')
          end
        end

        context 'when record has a tracked item' do
          let(:tracked_item_id) { 394_443 }

          before do
            create(:bd_lh_evidence_submission_success, claim_id:, tracked_item_id:)
          end

          it 'shows the evidenceSubmissions section in claim attributes' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end
            parsed_body = JSON.parse(response.body)
            evidence_submissions = parsed_body.dig('data', 'attributes', 'evidenceSubmissions')

            expect(evidence_submissions.size).to eq(1)

            submission = evidence_submissions[0]

            expect(submission['claim_id']).to eq(claim_id)
            expect(submission['document_type']).to eq('Birth Certificate')
            expect(submission['file_name']).to eq('testfile.txt')
            expect(submission['upload_status']).to eq('SUCCESS')
            expect(submission['lighthouse_upload']).to be(false)
            expect(submission['tracked_item_id']).to eq(tracked_item_id)
            expect(submission['tracked_item_display_name']).to eq('Submit buddy statement(s)')
            expect(submission['tracked_item_friendly_name']).to eq('Witness or corroboration statements')
            expect(submission['created_at']).to be_present
            expect(submission['delete_date']).to be_present
            expect(submission['acknowledgement_date']).to be_nil
            expect(submission['failed_date']).to be_nil
            expect(submission['id']).to be_present

            expect_metric('show', 'SUCCESS')
          end
        end

        context 'when evidence submission fetching fails' do
          before do
            # Allow normal EvidenceSubmission calls to work
            allow(EvidenceSubmission).to receive(:where).and_call_original

            # Mock to raise error when fetching evidence submissions for this specific claim
            allow(EvidenceSubmission).to receive(:where).with(claim_id: claim_id.to_s)
                                                        .and_raise(StandardError, 'Database connection error')
          end

          it 'logs the error and continues processing' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end

            expect(response).to have_http_status(:ok)
            expect(Rails.logger).to have_received(:error)
              .with('BenefitsClaimsController#show Error fetching evidence submissions', hash_including(:error_message,
                                                                                                        :claim_ids))
          end
        end

        context 'when adding evidence submissions fails' do
          before do
            create(:bd_lh_evidence_submission_success, claim_id:)

            # Mock add_evidence_submissions to raise an error
            allow_any_instance_of(V0::BenefitsClaimsController).to receive(:add_evidence_submissions)
              .and_raise(StandardError, 'Error processing evidence')
          end

          it 'logs the error with endpoint and claim_ids and continues processing' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end

            expect(response).to have_http_status(:ok)
            expect(Rails.logger).to have_received(:error)
              .with('BenefitsClaimsController#show Error adding evidence submissions', hash_including(:claim_ids))
          end
        end

        context 'when :cst_update_evidence_submission_on_show is enabled' do
          let(:pending_submission1) do
            create(:bd_evidence_submission_pending, claim_id:, request_id: 111_111)
          end
          let(:pending_submission2) do
            create(:bd_evidence_submission_pending, claim_id:, request_id: 222_222)
          end
          let(:polling_response) do
            double('Response', status: 200, body: {
                     'data' => {
                       'statuses' => [
                         { 'requestId' => 111_111, 'status' => 'SUCCESS' },
                         { 'requestId' => 222_222, 'status' => 'SUCCESS' }
                       ]
                     }
                   })
          end

          before do
            allow(Flipper).to receive(:enabled?).with(
              :cst_update_evidence_submission_on_show,
              instance_of(User)
            ).and_return(true)
            pending_submission1
            pending_submission2
            allow(BenefitsDocuments::DocumentsStatusPollingService).to receive(:call).and_return(polling_response)
            allow(BenefitsDocuments::UpdateDocumentsStatusService).to receive(:call)
          end

          it 'polls pending evidence submissions before adding them to response' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end

            expect(BenefitsDocuments::DocumentsStatusPollingService).to have_received(:call) do |request_ids|
              expect(request_ids).to contain_exactly(111_111, 222_222)
            end
            expect(BenefitsDocuments::UpdateDocumentsStatusService).to have_received(:call)
              .with(anything, polling_response.body)
            expect(StatsD).to have_received(:increment).with(
              'api.benefits_claims.show.upload_status_success',
              tags: V0::BenefitsClaimsController::STATSD_TAGS
            )
          end

          context 'when actually updating database records' do
            let(:test_pending_submission1) do
              create(:bd_evidence_submission_pending, claim_id:, request_id: 333_333)
            end
            let(:test_pending_submission2) do
              create(:bd_evidence_submission_pending, claim_id:, request_id: 444_444)
            end
            let(:test_polling_response) do
              double('Response', status: 200, body: {
                       'data' => {
                         'statuses' => [
                           { 'requestId' => 333_333, 'status' => 'SUCCESS' },
                           { 'requestId' => 444_444, 'status' => 'SUCCESS' }
                         ]
                       }
                     })
            end

            before do
              test_pending_submission1
              test_pending_submission2
              # Mock polling service but NOT update service - let it actually run
              allow(BenefitsDocuments::DocumentsStatusPollingService).to receive(:call)
                .and_return(test_polling_response)
            end

            it 'updates pending submissions to SUCCESS in database and returns updated status in response' do
              # Record initial statuses
              initial_status1 = test_pending_submission1.upload_status
              initial_status2 = test_pending_submission2.upload_status

              # Spy on UpdateDocumentsStatusService to verify it's called
              allow(BenefitsDocuments::UpdateDocumentsStatusService).to receive(:call).and_call_original

              VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                get(:show, params: { id: claim_id })
              end

              # Verify UpdateDocumentsStatusService was actually called
              expect(BenefitsDocuments::UpdateDocumentsStatusService).to have_received(:call)

              # Verify submissions were updated in database
              test_pending_submission1.reload
              test_pending_submission2.reload

              # Should have changed from PENDING (IN_PROGRESS) to SUCCESS
              expect(test_pending_submission1.upload_status).to eq('SUCCESS')
              expect(test_pending_submission2.upload_status).to eq('SUCCESS')
              expect(test_pending_submission1.upload_status).not_to eq(initial_status1)
              expect(test_pending_submission2.upload_status).not_to eq(initial_status2)

              # Verify the response includes the updated statuses
              response_body = JSON.parse(response.body)
              evidence_submissions = response_body.dig('data', 'attributes', 'evidenceSubmissions')

              expect(evidence_submissions).to be_present

              # Verify that all evidence submissions in the response have SUCCESS status
              # (since we updated all pending submissions to SUCCESS)
              success_statuses = evidence_submissions.select { |es| es['upload_status'] == 'SUCCESS' }
              expect(success_statuses.size).to eq(2)
            end
          end

          it 'skips polling when no pending submissions exist' do
            EvidenceSubmission.destroy_all

            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end

            expect(BenefitsDocuments::DocumentsStatusPollingService).not_to have_received(:call)
            expect(BenefitsDocuments::UpdateDocumentsStatusService).not_to have_received(:call)
          end

          context 'when polling service returns non-200 status' do
            let(:error_response) { double('Response', status: 500, body: 'Internal Server Error') }

            before do
              allow(BenefitsDocuments::DocumentsStatusPollingService).to receive(:call).and_return(error_response)
            end

            it 'does not call update service and logs error with all request IDs' do
              VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                get(:show, params: { id: claim_id })
              end

              expect(BenefitsDocuments::DocumentsStatusPollingService).to have_received(:call)
              expect(BenefitsDocuments::UpdateDocumentsStatusService).not_to have_received(:call)
              expect(response).to have_http_status(:ok)
              expect(Rails.logger).to have_received(:error) do |message, payload|
                expect(message).to eq('BenefitsClaimsController#show Error polling evidence submissions')
                expect(payload[:claim_id]).to eq(claim_id.to_s)
                expect(payload[:error_source]).to eq('polling')
                expect(payload[:response_status]).to eq(500)
                expect(payload[:response_body]).to eq('Internal Server Error')
                expect(payload[:lighthouse_document_request_ids]).to contain_exactly(111_111, 222_222)
                expect(payload[:timestamp]).to be_a(Time)
              end
              expect(StatsD).to have_received(:increment).with(
                'api.benefits_claims.show.upload_status_error',
                tags: V0::BenefitsClaimsController::STATSD_TAGS + ['error_source:polling']
              )
            end
          end

          context 'when polling raises an error' do
            before do
              allow(BenefitsDocuments::DocumentsStatusPollingService).to receive(:call)
                .and_raise(StandardError, 'Polling service error')
            end

            it 'logs the error and continues processing gracefully' do
              VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                get(:show, params: { id: claim_id })
              end

              expect(response).to have_http_status(:ok)
              expect(Rails.logger).to have_received(:error).with(
                'BenefitsClaimsController#show Error polling evidence submissions',
                hash_including(
                  claim_id: claim_id.to_s,
                  error_source: 'polling',
                  response_status: nil,
                  response_body: 'Polling service error',
                  timestamp: kind_of(Time)
                )
              )
              expect(StatsD).to have_received(:increment).with(
                'api.benefits_claims.show.upload_status_error',
                tags: V0::BenefitsClaimsController::STATSD_TAGS + ['error_source:polling']
              )
            end
          end

          context 'when update service raises an error' do
            before do
              allow(BenefitsDocuments::UpdateDocumentsStatusService).to receive(:call)
                .and_raise(StandardError, 'Update service error')
            end

            it 'logs the error and continues processing gracefully' do
              VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                get(:show, params: { id: claim_id })
              end

              expect(response).to have_http_status(:ok)
              expect(Rails.logger).to have_received(:error).with(
                'BenefitsClaimsController#show Error polling evidence submissions',
                hash_including(
                  claim_id: claim_id.to_s,
                  error_source: 'update',
                  response_status: 200,
                  response_body: 'Update service error',
                  timestamp: kind_of(Time)
                )
              )
              expect(StatsD).to have_received(:increment).with(
                'api.benefits_claims.show.upload_status_error',
                tags: V0::BenefitsClaimsController::STATSD_TAGS + ['error_source:update']
              )
            end
          end

          context 'when update service returns unsuccessful result with unknown IDs' do
            before do
              allow(BenefitsDocuments::UpdateDocumentsStatusService).to receive(:call).and_return(
                {
                  success: false,
                  response: {
                    status: 404,
                    body: 'Upload Request Async Status Not Found',
                    unknown_ids: [222_222]
                  }
                }
              )
            end

            it 'logs the error with unknown IDs only' do
              VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                get(:show, params: { id: claim_id })
              end

              expect(response).to have_http_status(:ok)
              expect(Rails.logger).to have_received(:error).with(
                'BenefitsClaimsController#show Error polling evidence submissions',
                hash_including(
                  claim_id: claim_id.to_s,
                  error_source: 'update',
                  lighthouse_document_request_ids: ['222222'],
                  response_status: 404,
                  timestamp: kind_of(Time)
                )
              )
              expect(StatsD).to have_received(:increment).with(
                'api.benefits_claims.show.upload_status_error',
                tags: V0::BenefitsClaimsController::STATSD_TAGS + ['error_source:update']
              )
            end
          end

          context 'when caching evidence submission polling' do
            let(:cache_pending_submission1) do
              create(:bd_evidence_submission_pending, claim_id:, request_id: 555_555)
            end
            let(:cache_pending_submission2) do
              create(:bd_evidence_submission_pending, claim_id:, request_id: 666_666)
            end
            let(:cache_polling_response) do
              double('Response', status: 200, body: {
                       'data' => {
                         'statuses' => [
                           { 'requestId' => 555_555, 'status' => 'SUCCESS' },
                           { 'requestId' => 666_666, 'status' => 'SUCCESS' }
                         ]
                       }
                     })
            end

            before do
              # Clear any existing submissions and create fresh ones for cache tests
              EvidenceSubmission.destroy_all
              cache_pending_submission1
              cache_pending_submission2

              allow(BenefitsDocuments::DocumentsStatusPollingService).to receive(:call)
                .and_return(cache_polling_response)
              allow(BenefitsDocuments::UpdateDocumentsStatusService).to receive(:call)
            end

            context 'when cache miss (first request or cache expired)' do
              it 'polls Lighthouse and caches the request_ids' do
                VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                  get(:show, params: { id: claim_id })
                end

                expect(BenefitsDocuments::DocumentsStatusPollingService).to have_received(:call)
                expect(StatsD).to have_received(:increment).with(
                  'api.benefits_claims.show.evidence_submission_cache_miss',
                  tags: V0::BenefitsClaimsController::STATSD_TAGS
                )

                # Verify cache was written using the model
                cache_record = EvidenceSubmissionPollStore.find(claim_id.to_s)
                expect(cache_record).not_to be_nil
                expect(cache_record.request_ids).to contain_exactly(555_555, 666_666)
              end
            end

            context 'when cache hit (same request_ids within TTL)' do
              before do
                # Pre-populate the cache with the same request_ids using the model
                EvidenceSubmissionPollStore.create(
                  claim_id: claim_id.to_s,
                  request_ids: [555_555, 666_666]
                )
              end

              it 'skips Lighthouse polling and returns early' do
                VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                  get(:show, params: { id: claim_id })
                end

                expect(BenefitsDocuments::DocumentsStatusPollingService).not_to have_received(:call)
                expect(BenefitsDocuments::UpdateDocumentsStatusService).not_to have_received(:call)
                expect(StatsD).to have_received(:increment).with(
                  'api.benefits_claims.show.evidence_submission_cache_hit',
                  tags: V0::BenefitsClaimsController::STATSD_TAGS
                )
              end
            end

            context 'when cache has different request_ids (natural invalidation)' do
              before do
                # Pre-populate the cache with different request_ids using the model
                EvidenceSubmissionPollStore.create(
                  claim_id: claim_id.to_s,
                  request_ids: [777_777, 888_888]
                )
              end

              it 'proceeds with polling due to different request_ids' do
                VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                  get(:show, params: { id: claim_id })
                end

                expect(BenefitsDocuments::DocumentsStatusPollingService).to have_received(:call)
                expect(StatsD).to have_received(:increment).with(
                  'api.benefits_claims.show.evidence_submission_cache_miss',
                  tags: V0::BenefitsClaimsController::STATSD_TAGS
                )
              end
            end

            context 'when cache read fails' do
              before do
                allow(EvidenceSubmissionPollStore).to receive(:find).and_raise(Redis::ConnectionError,
                                                                               'Connection refused')
              end

              it 'logs error and proceeds with polling' do
                VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                  get(:show, params: { id: claim_id })
                end

                expect(Rails.logger).to have_received(:error).with(
                  'BenefitsClaimsController#show Error reading evidence submission poll cache',
                  hash_including(
                    claim_id: claim_id.to_s,
                    error_class: 'Redis::ConnectionError'
                  )
                )
                expect(BenefitsDocuments::DocumentsStatusPollingService).to have_received(:call)
              end
            end

            context 'when cache write fails' do
              before do
                allow_any_instance_of(EvidenceSubmissionPollStore).to receive(:save).and_raise(Redis::ConnectionError,
                                                                                               'Connection refused')
              end

              it 'logs error but still completes the request successfully' do
                VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
                  get(:show, params: { id: claim_id })
                end

                expect(response).to have_http_status(:ok)
                expect(Rails.logger).to have_received(:error).with(
                  'BenefitsClaimsController#show Error writing evidence submission poll cache',
                  hash_including(
                    claim_id: claim_id.to_s,
                    error_class: 'Redis::ConnectionError'
                  )
                )
              end
            end
          end
        end

        context 'when :cst_update_evidence_submission_on_show is disabled' do
          let(:pending_submission1) do
            create(:bd_evidence_submission_pending, claim_id:, request_id: 111_111)
          end

          before do
            allow(Flipper).to receive(:enabled?).with(
              :cst_update_evidence_submission_on_show,
              instance_of(User)
            ).and_return(false)
            pending_submission1
            allow(BenefitsDocuments::DocumentsStatusPollingService).to receive(:call)
            allow(BenefitsDocuments::UpdateDocumentsStatusService).to receive(:call)
          end

          it 'does not poll evidence submissions' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end

            expect(BenefitsDocuments::DocumentsStatusPollingService).not_to have_received(:call)
            expect(BenefitsDocuments::UpdateDocumentsStatusService).not_to have_received(:call)
          end
        end
      end

      it 'returns a status of 200' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
          get(:show, params: { id: '600383363' })
        end

        expect(response).to have_http_status(:ok)
      end

      it 'adds a EVSSClaim record to the DB' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
          get(:show, params: { id: '600383363' })
        end

        expect(response).to have_http_status(:ok)
        expect(EVSSClaim.all.count).to equal(1)
      end

      it 'returns the correct value for canUpload' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
          get(:show, params: { id: '600383363' })
        end

        expect(response).to have_http_status(:ok)
        parsed_body = JSON.parse(response.body)
        expect(parsed_body['data']['attributes']['canUpload']).to be(true)
      end

      it 'logs the claim type details' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
          get(:show, params: { id: '600383363' })
        end

        expect(response).to have_http_status(:ok)
        expect(Rails.logger)
          .to have_received(:info)
          .with('Claim Type Details',
                { message_type: 'lh.cst.claim_types',
                  claim_type: 'Compensation',
                  claim_type_code: '020NEW',
                  num_contentions: 1,
                  ep_code: '020',
                  current_phase_back: false,
                  latest_phase_type: 'GATHERING_OF_EVIDENCE',
                  decision_letter_sent: false,
                  development_letter_sent: true,
                  claim_id: '600383363' })
      end

      it 'logs evidence requests/tracked items details' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
          get(:show, params: { id: '600383363' })
        end

        expect(response).to have_http_status(:ok)
        expect(Rails.logger)
          .to have_received(:info)
          .with('Evidence Request Types',
                { message_type: 'lh.cst.evidence_requests',
                  claim_id: '600383363',
                  tracked_item_id: 395_084,
                  tracked_item_type: 'PMR Pending',
                  tracked_item_status: 'NEEDED_FROM_OTHERS' })
        expect(Rails.logger)
          .to have_received(:info)
          .with('Evidence Request Types',
                { message_type: 'lh.cst.evidence_requests',
                  claim_id: '600383363',
                  tracked_item_id: 394_443,
                  tracked_item_type: 'Submit buddy statement(s)',
                  tracked_item_status: 'NEEDED_FROM_YOU' })
      end

      context 'claim title generator' do
        it 'returns claimType language modifications' do
          allow(Flipper).to receive(:enabled?).with(:cst_use_claim_title_generator_web).and_return(true)
          VCR.use_cassette('lighthouse/benefits_claims/show/200_death_claim_response') do
            get(:show, params: { id: '600229972' })
          end
          parsed_body = JSON.parse(response.body)

          expect(parsed_body['data']['attributes']['claimType'] == 'expenses related to death or burial').to be true
          expect(parsed_body['data']['attributes']['claimType'] == 'Death').to be false
        end
      end
    end

    context 'when not authorized' do
      it 'returns a status of 401' do
        VCR.use_cassette('lighthouse/benefits_claims/show/401_response') do
          get(:show, params: { id: claim_id })
        end

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when 'cst_multi_claim_provider' is disabled" do
      before do
        allow(Flipper).to receive(:enabled?).with(:cst_multi_claim_provider, anything).and_return(false)
      end

      context "when 'cst_evidence_requests_content_override' is disabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_evidence_requests_content_override,
                                                    instance_of(User)).and_return(false)
        end

        it 'returns tracked items with legacy content fields only' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end

          parsed_body = JSON.parse(response.body)
          tracked_items = parsed_body.dig('data', 'attributes', 'trackedItems')
          form_item = tracked_items.find { |i| i['displayName'] == '21-4142/21-4142a' }
          # Legacy fields should be populated
          expect(form_item['friendlyName']).to eq('Authorization to disclose information')
          expect(form_item['canUploadFile']).to be true
          expect(form_item['supportAliases']).to eq(['21-4142/21-4142a'])
          # New content override fields should NOT be present
          expect(form_item).not_to have_key('longDescription')
          expect(form_item).not_to have_key('nextSteps')
          expect(form_item).not_to have_key('noActionNeeded')
          expect(form_item).not_to have_key('isDBQ')
          expect(form_item).not_to have_key('isProperNoun')
          expect(form_item).not_to have_key('isSensitive')
          expect(form_item).not_to have_key('noProvidePrefix')
        end
      end

      context "when 'cst_evidence_requests_content_override' is enabled" do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_evidence_requests_content_override,
                                                    instance_of(User)).and_return(true)
        end

        it 'returns tracked items with new content override fields as well as legacy fields' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end

          parsed_body = JSON.parse(response.body)
          tracked_items = parsed_body.dig('data', 'attributes', 'trackedItems')
          form_item = tracked_items.find { |i| i['displayName'] == '21-4142/21-4142a' }
          # Existing fields should still be populated
          expect(form_item['friendlyName']).to eq('Authorization to disclose information')
          expect(form_item['canUploadFile']).to be true
          expect(form_item['supportAliases']).to eq(['21-4142/21-4142a'])
          # New structured content fields should be present
          expect(form_item['longDescription']).to be_a(Hash)
          expect(form_item['longDescription']).to have_key('blocks')
          expect(form_item['nextSteps']).to be_a(Hash)
          expect(form_item['nextSteps']).to have_key('blocks')
          # New boolean flags should be present
          expect(form_item).to have_key('noActionNeeded')
          expect(form_item).to have_key('isDBQ')
          expect(form_item).to have_key('isProperNoun')
          expect(form_item).to have_key('isSensitive')
          expect(form_item).to have_key('noProvidePrefix')
        end

        context 'when a tracked item does not have content overrides' do
          let(:test_display_name) { 'Submit buddy statement(s)' }

          before do
            allow(BenefitsClaims::TrackedItemContent).to receive(:find_by_display_name).and_call_original
            allow(BenefitsClaims::TrackedItemContent).to receive(:find_by_display_name)
              .with(test_display_name).and_return(nil)
          end

          it 'falls back to legacy content fields only' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: '600383363' })
            end

            parsed_body = JSON.parse(response.body)
            tracked_items = parsed_body.dig('data', 'attributes', 'trackedItems')
            buddy_statement_item = tracked_items.find { |i| i['displayName'] == test_display_name }
            # Should fall back to legacy content fields
            expect(buddy_statement_item['friendlyName']).to eq('Witness or corroboration statements')
            expect(buddy_statement_item['canUploadFile']).to be true
            expect(buddy_statement_item['supportAliases']).to eq(['Submit buddy statement(s)'])
            # New content override fields should NOT be present for items without overrides
            expect(buddy_statement_item).not_to have_key('longDescription')
            expect(buddy_statement_item).not_to have_key('nextSteps')
          end
        end
      end
    end
  end

  describe '#submit5103' do
    it 'returns a status of 200' do
      VCR.use_cassette('lighthouse/benefits_claims/submit5103/200_response') do
        post(:submit5103, params: { id: '600397108', trackedItemId: 12_345 }, as: :json)
      end

      expect(response).to have_http_status(:ok)
    end

    it 'returns a status of 404' do
      VCR.use_cassette('lighthouse/benefits_claims/submit5103/404_response') do
        post(:submit5103, params: { id: '600397108', trackedItemId: 12_345 }, as: :json)
      end

      expect(response).to have_http_status(:not_found)
    end

    context 'when LH takes too long to respond' do
      it 'returns a status of 504' do
        allow_any_instance_of(BenefitsClaims::Configuration).to receive(:post).and_raise(Faraday::TimeoutError)
        post(:submit5103, params: { id: '600397108', trackedItemId: 12_345 }, as: :json)

        expect(response).to have_http_status(:gateway_timeout)
      end
    end
  end

  describe '#failed_upload_evidence_submissions' do
    subject do
      get(:failed_upload_evidence_submissions)
    end

    context 'when the cst_show_document_upload_status is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(
          :cst_show_document_upload_status,
          instance_of(User)
        ).and_return(true)
      end

      context 'when unsuccessful' do
        context 'when the user is not signed in' do
          before do
            session.clear
          end

          it 'returns a status of 401' do
            subject

            expect(response).to have_http_status(:unauthorized)
          end
        end

        context 'when the user is signed in, but does not have valid credentials' do
          let(:invalid_user) { create(:user, :loa3, :accountable, :legacy_icn, participant_id: nil) }

          before do
            sign_in_as(invalid_user)
          end

          it 'returns a status of 403' do
            subject

            expect(response).to have_http_status(:forbidden)
            expect(response.body).to include('Forbidden')
          end
        end

        context 'when the user is signed in and has valid credentials' do
          before do
            create(:bd_lh_evidence_submission_failed_type2_error, claim_id:, user_account:)
          end

          context 'when the ICN is not found' do
            it 'returns a status of 404' do
              VCR.use_cassette('lighthouse/benefits_claims/show/404_response') do
                subject
              end

              expect(response).to have_http_status(:not_found)
            end
          end

          context 'when there is a gateway timeout' do
            it 'returns a status of 504' do
              VCR.use_cassette('lighthouse/benefits_claims/show/504_response') do
                subject
              end

              expect(response).to have_http_status(:gateway_timeout)
            end
          end

          context 'when Lighthouse takes too long to respond' do
            it 'returns a status of 504' do
              allow_any_instance_of(BenefitsClaims::Configuration).to receive(:get).and_raise(Faraday::TimeoutError)
              subject

              expect(response).to have_http_status(:gateway_timeout)
            end
          end
        end
      end

      context 'when successful' do
        before do
          create(:bd_lh_evidence_submission_success, claim_id:, user_account:)
          create(:bd_lh_evidence_submission_failed_type1_error, claim_id:, user_account:)
          create(:bd_lh_evidence_submission_failed_type2_error, claim_id:, user_account:)
        end

        it 'returns an array of only the failed evidence submissions' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            subject
          end

          expect(response).to have_http_status(:ok)
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['data'].size).to eq(2)
          parsed_response['data'].each do |submission|
            expect(submission['document_type']).to eq('Birth Certificate')
            expect(submission['file_name']).to eq('test.txt')
            expect(submission['upload_status']).to eq('FAILED')
            expect(submission['claim_id']).to eq(claim_id)
            expect(submission['lighthouse_upload']).to be(false)
            expect(submission['failed_date']).to be_present
            expect(submission['acknowledgement_date']).to be_present
            expect(submission['created_at']).to be_present
            expect(submission['id']).to be_present
          end
        end

        context 'when multiple claims are returned for the evidence submission records' do
          before do
            create(:bd_lh_evidence_submission_failed_type1_error, claim_id: 600_229_972, user_account:)
          end

          it 'returns evidence submissions for all claims' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              VCR.use_cassette('lighthouse/benefits_claims/show/200_death_claim_response') do
                subject
              end
            end

            expect(response).to have_http_status(:ok)
            parsed_response = JSON.parse(response.body)
            expect(parsed_response['data'].size).to eq(3)

            # Verify all submissions have required fields
            parsed_response['data'].each do |submission|
              expect(submission['document_type']).to eq('Birth Certificate')
              expect(submission['file_name']).to eq('test.txt')
              expect(submission['upload_status']).to eq('FAILED')
              expect(submission['lighthouse_upload']).to be(false)
              expect(submission['failed_date']).to be_present
              expect(submission['acknowledgement_date']).to be_present
              expect(submission['created_at']).to be_present
              expect(submission['id']).to be_present
              expect(submission['claim_id']).to be_present
            end

            # Verify submissions are from different claims
            claim_ids = parsed_response['data'].map { |s| s['claim_id'] }.uniq
            expect(claim_ids.size).to eq(2)
            expect(claim_ids).to include(claim_id, 600_229_972)
          end
        end

        context 'when no failed submissions exist' do
          before do
            EvidenceSubmission.destroy_all
          end

          it 'returns an empty array' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              subject
            end

            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)).to eq({ 'data' => [] })
          end
        end
      end
    end

    context 'when :cst_show_document_upload_status is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(
          :cst_show_document_upload_status,
          instance_of(User)
        ).and_return(false)
      end

      context 'when unsuccessful' do
        context 'when the user is not signed in' do
          before do
            session.clear
          end

          it 'returns a status of 401' do
            subject

            expect(response).to have_http_status(:unauthorized)
          end
        end

        context 'when the user is signed in, but does not have valid credentials' do
          let(:invalid_user) { create(:user, :loa3, :accountable, :legacy_icn, participant_id: nil) }

          before do
            sign_in_as(invalid_user)
          end

          it 'returns a status of 403' do
            subject

            expect(response).to have_http_status(:forbidden)
            expect(response.body).to include('Forbidden')
          end
        end

        context 'when the user is signed in and has valid credentials' do
          it 'returns an empty array' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              subject
            end

            expect(JSON.parse(response.body)).to eq({ 'data' => [] })
          end
        end
      end

      context 'when successful' do
        it 'returns an empty array' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            subject
          end

          expect(JSON.parse(response.body)).to eq({ 'data' => [] })
        end
      end
    end
  end

  describe 'duplicate prevention integration tests' do
    let(:claim_id) { 600_383_363 }

    context 'when :cst_show_document_upload_status is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(
          :cst_show_document_upload_status,
          instance_of(User)
        ).and_return(true)
      end

      context 'when evidence submission exists without duplicates' do
        let(:tracked_item_id) { 394_443 } # This is a tracked item in the VCR cassette
        let(:file_name) { 'unique_document.pdf' }

        before do
          # Create an evidence submission that should appear in "files in progress"
          create(:bd_evidence_submission_pending,
                 claim_id:,
                 tracked_item_id:,
                 user_account:,
                 template_metadata: {
                   personalisation: {
                     file_name:,
                     document_type: 'Medical Record'
                   }
                 }.to_json)
        end

        it 'includes the evidence submission in the response' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: claim_id })
          end

          expect(response).to have_http_status(:ok)
          parsed_body = JSON.parse(response.body)
          evidence_submissions = parsed_body.dig('data', 'attributes', 'evidenceSubmissions')

          # The evidence submission should be included because no duplicate exists in VCR cassette
          expect(evidence_submissions.size).to eq(1)
          expect(evidence_submissions[0]['file_name']).to eq(file_name)
          expect_metric('show', 'IN_PROGRESS', 1)
        end
      end

      context 'when filter_duplicate_evidence_submissions is called directly' do
        let(:controller) { described_class.new }
        let(:mock_evidence_submission) do
          double('EvidenceSubmission',
                 id: 1,
                 template_metadata: {
                   personalisation: {
                     file_name: 'test_document.pdf'
                   }
                 }.to_json)
        end

        it 'correctly filters duplicates when supporting documents match' do
          claim_data = {
            'attributes' => {
              'supportingDocuments' => [
                { 'originalFileName' => 'test_document.pdf' },
                { 'originalFileName' => 'other_document.pdf' }
              ]
            }
          }

          result = controller.send(:filter_duplicate_evidence_submissions, [mock_evidence_submission], claim_data)
          expect(result).to be_empty
        end

        it 'correctly includes evidence submissions when no duplicates exist' do
          claim_data = {
            'attributes' => {
              'supportingDocuments' => [
                { 'originalFileName' => 'different_document.pdf' },
                { 'originalFileName' => 'other_document.pdf' }
              ]
            }
          }

          result = controller.send(:filter_duplicate_evidence_submissions, [mock_evidence_submission], claim_data)
          expect(result).to eq([mock_evidence_submission])
        end
      end
    end
  end

  describe 'private methods' do
    let(:controller) { described_class.new }
    let(:claim_id) { '600383363' }

    describe '#filter_duplicate_evidence_submissions' do
      let(:evidence_submission1) do
        double('EvidenceSubmission',
               id: 1,
               template_metadata: { personalisation: { file_name: 'document1.pdf' } }.to_json)
      end
      let(:evidence_submission2) do
        double('EvidenceSubmission',
               id: 2,
               template_metadata: { personalisation: { file_name: 'document2.pdf' } }.to_json)
      end
      let(:evidence_submission3) do
        double('EvidenceSubmission',
               id: 3,
               template_metadata: { personalisation: { file_name: 'document3.pdf' } }.to_json)
      end
      let(:evidence_submissions) { [evidence_submission1, evidence_submission2, evidence_submission3] }

      let(:claim_data) do
        {
          'id' => claim_id,
          'attributes' => {
            'supportingDocuments' => supporting_documents
          }
        }
      end

      context 'when no supporting documents exist' do
        let(:supporting_documents) { [] }

        it 'returns all evidence submissions unchanged' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)
          expect(result).to eq(evidence_submissions)
        end
      end

      context 'when supportingDocuments is nil' do
        let(:claim_data) do
          {
            'id' => claim_id,
            'attributes' => {}
          }
        end

        it 'returns all evidence submissions unchanged' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)
          expect(result).to eq(evidence_submissions)
        end
      end

      context 'when supporting documents exist but no file names match' do
        let(:supporting_documents) do
          [
            { 'originalFileName' => 'different1.pdf' },
            { 'originalFileName' => 'different2.pdf' }
          ]
        end

        it 'returns all evidence submissions unchanged' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)
          expect(result).to eq(evidence_submissions)
        end
      end

      context 'when supporting documents contain matching file names' do
        let(:supporting_documents) do
          [
            { 'originalFileName' => 'document1.pdf' },  # matches evidence_submission1
            { 'originalFileName' => 'different.pdf' },
            { 'originalFileName' => 'document3.pdf' }   # matches evidence_submission3
          ]
        end

        it 'filters out evidence submissions with matching file names' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)
          expect(result).to eq([evidence_submission2])
          expect(result).not_to include(evidence_submission1)
          expect(result).not_to include(evidence_submission3)
        end
      end

      context 'when supporting documents have nil originalFileName' do
        let(:supporting_documents) do
          [
            { 'originalFileName' => nil },
            { 'originalFileName' => 'document2.pdf' }
          ]
        end

        it 'handles nil originalFileName gracefully and filters matching files' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)
          expect(result).to eq([evidence_submission1, evidence_submission3])
          expect(result).not_to include(evidence_submission2)
        end
      end

      context 'when evidence submission has invalid JSON metadata' do
        let(:evidence_submission_invalid) do
          double('EvidenceSubmission',
                 id: 4,
                 template_metadata: 'invalid json')
        end
        let(:evidence_submissions) { [evidence_submission1, evidence_submission_invalid] }
        let(:supporting_documents) do
          [{ 'originalFileName' => 'document1.pdf' }]
        end

        before do
          allow(Rails.logger).to receive(:warn)
        end

        it 'logs warning but does not filter out submission with invalid metadata' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)

          expect(result).to eq([evidence_submission_invalid])
          expect(result).not_to include(evidence_submission1)
          expect(Rails.logger).to have_received(:error).with(
            '[BenefitsClaimsController] Error parsing evidence submission metadata',
            { evidence_submission_id: 4 }
          )
        end
      end

      context 'when evidence submission has nil template_metadata' do
        let(:evidence_submission_nil) do
          double('EvidenceSubmission',
                 id: 5,
                 template_metadata: nil)
        end
        let(:evidence_submissions) { [evidence_submission1, evidence_submission_nil] }
        let(:supporting_documents) do
          [{ 'originalFileName' => 'document1.pdf' }]
        end

        it 'does not filter out submission with nil metadata' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)

          expect(result).to eq([evidence_submission_nil])
          expect(result).not_to include(evidence_submission1)
        end
      end

      context 'when evidence submission has valid JSON but missing personalisation key' do
        let(:evidence_submission_missing_key) do
          double('EvidenceSubmission',
                 id: 6,
                 template_metadata: { other_data: 'value' }.to_json)
        end
        let(:evidence_submissions) { [evidence_submission1, evidence_submission_missing_key] }
        let(:supporting_documents) do
          [{ 'originalFileName' => 'document1.pdf' }]
        end

        before do
          allow(Rails.logger).to receive(:warn)
        end

        it 'logs warning about missing personalisation and does not filter out submission' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)

          expect(result).to eq([evidence_submission_missing_key])
          expect(result).not_to include(evidence_submission1)
          expect(Rails.logger).to have_received(:warn).with(
            '[BenefitsClaimsController] Missing or invalid personalisation in evidence submission metadata',
            { evidence_submission_id: 6 }
          )
        end
      end

      context 'when evidence submission has personalisation as non-hash' do
        let(:evidence_submission_invalid_personalisation) do
          double('EvidenceSubmission',
                 id: 7,
                 template_metadata: { personalisation: 'not a hash' }.to_json)
        end
        let(:evidence_submissions) { [evidence_submission1, evidence_submission_invalid_personalisation] }
        let(:supporting_documents) do
          [{ 'originalFileName' => 'document1.pdf' }]
        end

        before do
          allow(Rails.logger).to receive(:warn)
        end

        it 'logs warning about invalid personalisation and does not filter out submission' do
          result = controller.send(:filter_duplicate_evidence_submissions, evidence_submissions, claim_data)

          expect(result).to eq([evidence_submission_invalid_personalisation])
          expect(result).not_to include(evidence_submission1)
          expect(Rails.logger).to have_received(:warn).with(
            '[BenefitsClaimsController] Missing or invalid personalisation in evidence submission metadata',
            { evidence_submission_id: 7 }
          )
        end
      end
    end
  end

  describe '#get_claims_from_providers' do
    let(:mock_provider_class) { double('MockProviderClass', name: 'MockProvider') }
    let(:mock_provider) { double('MockProvider') }
    let(:second_provider_class) { double('SecondProviderClass', name: 'SecondProvider') }
    let(:second_provider) { double('SecondProvider') }

    before do
      controller.instance_variable_set(:@current_user, user)
      allow(BenefitsClaims::Providers::ProviderRegistry)
        .to receive(:enabled_provider_classes)
        .with(user)
        .and_return(providers)
    end

    context 'with single provider' do
      let(:providers) { [mock_provider_class] }
      let(:claims_response) do
        {
          'data' => [
            { 'id' => '123', 'attributes' => { 'claimType' => 'Compensation' } }
          ]
        }
      end

      before do
        allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
        allow(mock_provider).to receive(:get_claims).and_return(claims_response)
      end

      it 'returns claims from the single provider' do
        result = controller.send(:get_claims_from_providers)

        expect(result['data']).to eq(claims_response['data'])
        expect(result['meta']).to eq({})
        expect(mock_provider).to have_received(:get_claims)
      end
    end

    context 'with multiple providers' do
      let(:providers) { [mock_provider_class, second_provider_class] }
      let(:first_claims) do
        {
          'data' => [
            { 'id' => '123', 'attributes' => { 'claimType' => 'Compensation' } }
          ]
        }
      end
      let(:second_claims) do
        {
          'data' => [
            { 'id' => '456', 'attributes' => { 'claimType' => 'Pension' } }
          ]
        }
      end

      before do
        allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
        allow(mock_provider).to receive(:get_claims).and_return(first_claims)
        allow(second_provider_class).to receive(:new).with(user).and_return(second_provider)
        allow(second_provider).to receive(:get_claims).and_return(second_claims)
      end

      it 'aggregates claims from all providers' do
        result = controller.send(:get_claims_from_providers)

        expect(result['data'].length).to eq(2)
        expect(result['data'].map { |c| c['id'] }).to contain_exactly('123', '456')
        expect(mock_provider).to have_received(:get_claims)
        expect(second_provider).to have_received(:get_claims)
      end

      it 'does not include provider_errors in meta when all succeed' do
        result = controller.send(:get_claims_from_providers)

        expect(result['meta']).to eq({})
      end
    end

    context 'with provider errors' do
      let(:providers) { [mock_provider_class, second_provider_class] }
      let(:error_message) { 'Provider temporarily unavailable' }
      let(:second_claims) do
        {
          'data' => [
            { 'id' => '456', 'attributes' => { 'claimType' => 'Pension' } }
          ]
        }
      end

      before do
        allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
        allow(mock_provider).to receive(:get_claims).and_raise(StandardError, error_message)
        allow(mock_provider_class).to receive(:name).and_return('MockProvider')
        allow(second_provider_class).to receive(:new).with(user).and_return(second_provider)
        allow(second_provider).to receive(:get_claims).and_return(second_claims)
        allow(Rails.logger).to receive(:warn)
        allow(StatsD).to receive(:increment)
      end

      it 'continues processing other providers' do
        result = controller.send(:get_claims_from_providers)

        expect(result['data'].length).to eq(1)
        expect(result['data'].first['id']).to eq('456')
      end

      it 'includes provider errors in meta' do
        result = controller.send(:get_claims_from_providers)

        expect(result['meta']['provider_errors']).to be_present
        expect(result['meta']['provider_errors'].first['provider']).to eq('MockProvider')
        expect(result['meta']['provider_errors'].first['error']).to eq(error_message)
      end

      it 'logs the warning' do
        controller.send(:get_claims_from_providers)

        expect(Rails.logger).to have_received(:warn).with(
          'Provider MockProvider failed',
          hash_including(provider: 'MockProvider', error_class: 'StandardError')
        )
      end

      it 'increments StatsD metric' do
        controller.send(:get_claims_from_providers)

        expect(StatsD).to have_received(:increment).with(
          'api.benefits_claims.provider_error',
          hash_including(tags: array_including('provider:MockProvider'))
        )
      end
    end

    context 'when all providers fail' do
      let(:providers) { [mock_provider_class, second_provider_class] }

      before do
        allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
        allow(mock_provider).to receive(:get_claims).and_raise(StandardError, 'Error 1')
        allow(mock_provider_class).to receive(:name).and_return('MockProvider')
        allow(second_provider_class).to receive(:new).with(user).and_return(second_provider)
        allow(second_provider).to receive(:get_claims).and_raise(StandardError, 'Error 2')
        allow(second_provider_class).to receive(:name).and_return('SecondProvider')
        allow(Rails.logger).to receive(:error)
        allow(StatsD).to receive(:increment)
      end

      it 'returns empty data array with errors in meta' do
        result = controller.send(:get_claims_from_providers)

        expect(result['data']).to eq([])
        expect(result['meta']['provider_errors']).to be_present
        expect(result['meta']['provider_errors'].length).to eq(2)
      end
    end

    context 'when provider returns unexpected response structure' do
      let(:providers) { [mock_provider_class] }

      before do
        allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
      end

      it 'logs warning when provider returns nil' do
        allow(mock_provider).to receive(:get_claims).and_return(nil)

        expect(Rails.logger).to receive(:warn).with(
          'Provider MockProvider returned nil from get_claims'
        )

        result = controller.send(:get_claims_from_providers)
        expect(result['data']).to eq([])
      end

      it 'logs error when provider returns hash without data key' do
        allow(mock_provider).to receive(:get_claims).and_return({ 'meta' => {} })

        expect(Rails.logger).to receive(:error).with(
          'Provider MockProvider returned unexpected structure from get_claims',
          hash_including(provider: 'MockProvider', response_class: 'Hash')
        )

        result = controller.send(:get_claims_from_providers)
        expect(result['data']).to eq([])
      end

      it 'logs error when provider returns non-hash' do
        allow(mock_provider).to receive(:get_claims).and_return('invalid')

        expect(Rails.logger).to receive(:error).with(
          'Provider MockProvider returned unexpected structure from get_claims',
          hash_including(provider: 'MockProvider', response_class: 'String')
        )

        result = controller.send(:get_claims_from_providers)
        expect(result['data']).to eq([])
      end

      it 'does not log when provider returns valid structure with nil data' do
        allow(mock_provider).to receive(:get_claims).and_return({ 'data' => nil })

        expect(Rails.logger).not_to receive(:warn)

        result = controller.send(:get_claims_from_providers)
        expect(result['data']).to eq([])
      end

      it 'does not log when provider returns valid structure with empty data' do
        allow(mock_provider).to receive(:get_claims).and_return({ 'data' => [] })

        expect(Rails.logger).not_to receive(:warn)

        result = controller.send(:get_claims_from_providers)
        expect(result['data']).to eq([])
      end
    end
  end

  describe '#get_claim_from_providers' do
    let(:claim_id) { '123456' }
    let(:mock_provider_class) { double('MockProviderClass', name: 'MockProvider') }
    let(:mock_provider) { double('MockProvider') }
    let(:second_provider_class) { double('SecondProviderClass', name: 'SecondProvider') }
    let(:second_provider) { double('SecondProvider') }

    before do
      controller.instance_variable_set(:@current_user, user)
      allow(BenefitsClaims::Providers::ProviderRegistry)
        .to receive(:enabled_provider_classes)
        .with(user)
        .and_return(providers)
    end

    context 'with single provider' do
      let(:providers) { [mock_provider_class] }
      let(:claim_response) do
        {
          'data' => {
            'id' => claim_id,
            'attributes' => { 'claimType' => 'Compensation' }
          }
        }
      end

      before do
        allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
        allow(mock_provider).to receive(:get_claim).with(claim_id).and_return(claim_response)
      end

      it 'returns claim from the provider' do
        result = controller.send(:get_claim_from_providers, claim_id)

        expect(result).to eq(claim_response)
        expect(mock_provider).to have_received(:get_claim).with(claim_id)
      end
    end

    context 'with multiple providers' do
      let(:providers) { [mock_provider_class, second_provider_class] }
      let(:claim_response) do
        {
          'data' => {
            'id' => claim_id,
            'attributes' => { 'claimType' => 'Compensation' }
          }
        }
      end

      context 'when first provider has the claim' do
        before do
          allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
          allow(mock_provider).to receive(:get_claim).with(claim_id).and_return(claim_response)
        end

        it 'returns claim from first provider' do
          result = controller.send(:get_claim_from_providers, claim_id)

          expect(result).to eq(claim_response)
          expect(mock_provider).to have_received(:get_claim).with(claim_id)
        end

        it 'does not call second provider' do
          allow(second_provider_class).to receive(:new)

          controller.send(:get_claim_from_providers, claim_id)

          expect(second_provider_class).not_to have_received(:new)
        end
      end

      context 'when first provider does not have claim but second does' do
        before do
          allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
          allow(mock_provider).to receive(:get_claim).with(claim_id)
                                                     .and_raise(Common::Exceptions::RecordNotFound, claim_id)
          allow(mock_provider_class).to receive(:name).and_return('MockProvider')
          allow(second_provider_class).to receive(:new).with(user).and_return(second_provider)
          allow(second_provider).to receive(:get_claim).with(claim_id).and_return(claim_response)
          allow(Rails.logger).to receive(:info)
        end

        it 'returns claim from second provider' do
          result = controller.send(:get_claim_from_providers, claim_id)

          expect(result).to eq(claim_response)
          expect(second_provider).to have_received(:get_claim).with(claim_id)
        end

        it 'logs info about first provider not having claim' do
          controller.send(:get_claim_from_providers, claim_id)

          expect(Rails.logger).to have_received(:info).with(
            "Provider MockProvider doesn't have claim",
            hash_including(error_class: 'Common::Exceptions::RecordNotFound')
          )
        end
      end

      context 'when no provider has the claim' do
        before do
          allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
          allow(mock_provider).to receive(:get_claim).with(claim_id)
                                                     .and_raise(Common::Exceptions::RecordNotFound, claim_id)
          allow(mock_provider_class).to receive(:name).and_return('MockProvider')
          allow(second_provider_class).to receive(:new).with(user).and_return(second_provider)
          allow(second_provider).to receive(:get_claim).with(claim_id)
                                                       .and_raise(Common::Exceptions::RecordNotFound, claim_id)
          allow(second_provider_class).to receive(:name).and_return('SecondProvider')
          allow(Rails.logger).to receive(:info)
        end

        it 'raises RecordNotFound exception' do
          expect do
            controller.send(:get_claim_from_providers, claim_id)
          end.to raise_error(Common::Exceptions::RecordNotFound)
        end

        it 'logs info about both providers not having claim' do
          begin
            controller.send(:get_claim_from_providers, claim_id)
          rescue Common::Exceptions::RecordNotFound
            # Expected
          end

          expect(Rails.logger).to have_received(:info).twice
        end
      end

      context 'when first provider raises unexpected error but second succeeds' do
        let(:error_message) { 'Unexpected error occurred' }

        before do
          allow(mock_provider_class).to receive(:new).with(user).and_return(mock_provider)
          allow(mock_provider).to receive(:get_claim).with(claim_id)
                                                     .and_raise(StandardError, error_message)
          allow(mock_provider_class).to receive(:name).and_return('MockProvider')
          allow(second_provider_class).to receive(:new).with(user).and_return(second_provider)
          allow(second_provider).to receive(:get_claim).with(claim_id).and_return(claim_response)
          allow(Rails.logger).to receive(:error)
          allow(StatsD).to receive(:increment)
        end

        it 'returns claim from second provider' do
          result = controller.send(:get_claim_from_providers, claim_id)

          expect(result).to eq(claim_response)
          expect(second_provider).to have_received(:get_claim).with(claim_id)
        end

        it 'logs error about first provider failure' do
          controller.send(:get_claim_from_providers, claim_id)

          expect(Rails.logger).to have_received(:error).with(
            'Provider MockProvider error fetching claim',
            hash_including(error_class: 'StandardError')
          )
        end

        it 'increments StatsD error metric' do
          controller.send(:get_claim_from_providers, claim_id)

          expect(StatsD).to have_received(:increment).with(
            'api.benefits_claims.get_claim.provider_error',
            tags: V0::BenefitsClaimsController::STATSD_TAGS + ['provider:MockProvider']
          )
        end
      end
    end
  end
end
