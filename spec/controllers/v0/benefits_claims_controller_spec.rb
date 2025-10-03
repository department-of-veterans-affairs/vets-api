# frozen_string_literal: true

require 'rails_helper'

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
    allow(Rails.logger).to receive(:error)
    allow(StatsD).to receive(:increment)
    allow_any_instance_of(BenefitsClaims::Configuration).to receive(:access_token).and_return(token)
  end

  describe '#index' do
    context 'when successful' do
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
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end
        parsed_body = JSON.parse(response.body)
        death_claims = parsed_body['data'].select { |claim| claim['attributes']['claimType'] == 'expenses related to death or burial' }

        expect(death_claims.count).to eq(1)
        death_claim = death_claims.first

        expect(death_claim['attributes']['displayTitle']).to eq('Claim for expenses related to death or burial')
        expect(death_claim['attributes']['claimTypeBase']).to eq('expenses related to death or burial claim')
      end

      it 'sets correct titles for claims with claimTypeCode but null claimType' do
        VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
          get(:index)
        end
        parsed_body = JSON.parse(response.body)
        code_only_claims = parsed_body['data'].select { |claim| claim['attributes']['claimType'].nil? && !claim['attributes']['claimTypeCode'].nil? }

        expect(code_only_claims.count).to eq(2)

        # Check that both claims with claimTypeCode get default titles (since these codes aren't in our mapping)
        code_only_claims.each do |claim|
          expect(claim['attributes']['displayTitle']).to be_nil
          expect(claim['attributes']['claimTypeBase']).to be_nil
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
        expect(pension_claim['attributes']['claimTypeBase']).to eq('veterans pension claim')
      end

      context 'when :cst_show_document_upload_status is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(
            :cst_show_document_upload_status,
            instance_of(User)
          ).and_return(false)
        end

        it 'does not return hasFailedUploads field' do
          VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
            get(:index)
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body['data']
          .select { |claim| claim['attributes']['hasFailedUploads'] }).to eq []
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

        context 'when record has a SUCCESS upload status' do
          before do
            create(:bd_lh_evidence_submission_success, claim_id:)
          end

          it 'returns hasFailedUploads false' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end

            parsed_body = JSON.parse(response.body)
            expect(parsed_body['data'].select do |claim|
              claim['id'] == claim_id.to_s
            end[0]['attributes']['hasFailedUploads'])
              .to be false
            expect_metric('index', 'SUCCESS')
          end
        end

        context 'when record has a FAILED upload status' do
          before do
            create(:bd_lh_evidence_submission_failed_type1_error, claim_id:)
          end

          it 'returns hasFailedUploads false' do
            VCR.use_cassette('lighthouse/benefits_claims/index/200_response') do
              get(:index)
            end

            parsed_body = JSON.parse(response.body)
            expect(parsed_body['data'].select do |claim|
              claim['id'] == claim_id.to_s
            end[0]['attributes']['hasFailedUploads'])
              .to be true
            expect_metric('index', 'FAILED')
          end
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
              .with(a_string_including('BenefitsClaimsController#index'))
          end
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

    context 'when ICN not found' do
      it 'returns a status of 404' do
        VCR.use_cassette('lighthouse/benefits_claims/index/404_response') do
          get(:index)
        end

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when there is a gateway timeout' do
      it 'returns a status of 504' do
        VCR.use_cassette('lighthouse/benefits_claims/index/504_response') do
          get(:index)
        end

        expect(response).to have_http_status(:gateway_timeout)
      end
    end

    context 'when LH takes too long to respond' do
      it 'returns a status of 504' do
        allow_any_instance_of(BenefitsClaims::Configuration).to receive(:get).and_raise(Faraday::TimeoutError)
        get(:index)

        expect(response).to have_http_status(:gateway_timeout)
      end
    end
  end

  describe '#show' do
    context 'when successful' do
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

        it 'excludes Attorney Fees, Secondary Action Required, and Stage 2 Development tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          names = parsed_body.dig('data', 'attributes', 'trackedItems').map { |i| i['displayName'] }
          expect(names).not_to include('Attorney Fees')
          expect(names).not_to include('Secondary Action Required')
          expect(names).not_to include('Stage 2 Development')
        end
      end

      context 'when :cst_suppress_evidence_requests_website is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(false)
        end

        it 'includes Attorney Fees, Secondary Action Required, and Stage 2 Development tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          names = parsed_body.dig('data', 'attributes', 'trackedItems').map { |i| i['displayName'] }
          expect(names).to include('Attorney Fees')
          expect(names).to include('Secondary Action Required')
          expect(names).to include('Stage 2 Development')
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
        context 'when record does not have a tracked item' do
          before do
            allow(Flipper).to receive(:enabled?).with(
              :cst_show_document_upload_status,
              instance_of(User)
            ).and_return(true)
            create(:bd_lh_evidence_submission_success, claim_id:)
          end

          it 'shows the evidenceSubmissions section in claim attributes' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end
            parsed_body = JSON.parse(response.body)
            expect(parsed_body.dig('data', 'attributes', 'evidenceSubmissions').size).to eq(1)
            expect_metric('show', 'SUCCESS')
          end
        end

        context 'when record has a tracked item' do
          let(:tracked_item_id) { 394_443 }

          before do
            allow(Flipper).to receive(:enabled?).with(
              :cst_show_document_upload_status,
              instance_of(User)
            ).and_return(true)
            create(:bd_lh_evidence_submission_success, claim_id:, tracked_item_id:)
          end

          it 'shows the evidenceSubmissions section in claim attributes' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end
            parsed_body = JSON.parse(response.body)
            evidence_submissions = parsed_body.dig('data', 'attributes', 'evidenceSubmissions')
            expect(evidence_submissions.size).to eq(1)
            expect(evidence_submissions[0]['tracked_item_id']).to eq(tracked_item_id)
            expect_metric('show', 'SUCCESS')
          end
        end

        context 'when evidence submission metrics reporting fails' do
          before do
            # Allow normal EvidenceSubmission calls to work
            allow(EvidenceSubmission).to receive(:where).and_call_original

            # Mock specifically for the metrics method pattern (claim_id with an array)
            # Show endpoint passes a single ID converted to array in the metrics method
            allow(EvidenceSubmission).to receive(:where).with(claim_id: kind_of(Array))
                                                        .and_raise(StandardError, 'Database connection error')
          end

          it 'logs the error and continues processing' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end

            expect(response).to have_http_status(:ok)
            expect(Rails.logger).to have_received(:error)
              .with(a_string_including('BenefitsClaimsController#show'))
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

      it 'returns claimType language modifications' do
        VCR.use_cassette('lighthouse/benefits_claims/show/200_death_claim_response') do
          get(:show, params: { id: '600229972' })
        end
        parsed_body = JSON.parse(response.body)

        expect(parsed_body['data']['attributes']['claimType'] == 'expenses related to death or burial').to be true
        expect(parsed_body['data']['attributes']['claimType'] == 'Death').to be false
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

    context 'when ICN not found' do
      it 'returns a status of 404' do
        VCR.use_cassette('lighthouse/benefits_claims/show/404_response') do
          get(:show, params: { id: claim_id })
        end

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when there is a gateway timeout' do
      it 'returns a status of 504' do
        VCR.use_cassette('lighthouse/benefits_claims/show/504_response') do
          get(:show, params: { id: claim_id })
        end

        expect(response).to have_http_status(:gateway_timeout)
      end
    end

    context 'when LH takes too long to respond' do
      it 'returns a status of 504' do
        allow_any_instance_of(BenefitsClaims::Configuration).to receive(:get).and_raise(Faraday::TimeoutError)
        get(:show, params: { id: claim_id })

        expect(response).to have_http_status(:gateway_timeout)
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
          expect(parsed_response['data'].first['document_type']).to eq('Birth Certificate')
          expect(parsed_response['data'].second['document_type']).to eq('Birth Certificate')
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
end
