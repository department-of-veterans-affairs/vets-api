# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::BenefitsClaimsController, type: :controller do
  let(:user) { create(:user, :loa3, :accountable, icn: '123498767V234859') }
  let(:dependent_user) { build(:dependent_user_with_relationship, :loa3) }
  let(:claim_id) { 600_383_363 } # This is the claim in the vcr cassettes that we are using

  before do
    sign_in_as(user)

    token = 'fake_access_token'

    allow(Rails.logger).to receive(:info)
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

      context 'when :cst_show_document_upload_status is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_show_document_upload_status).and_return(false)
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
          allow(Flipper).to receive(:enabled?).with(:cst_show_document_upload_status).and_return(true)
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
      context 'when cst_override_reserve_records_website flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_override_reserve_records_website).and_return(true)
        end

        it 'overrides the tracked item status to NEEDED_FROM_OTHERS' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 2,
                                 'displayName')).to eq('RV1 - Reserve Records Request')
          # In the cassette, this value is NEEDED_FROM_YOU
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 2, 'status')).to eq('NEEDED_FROM_OTHERS')
        end
      end

      context 'when cst_override_reserve_records_website flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_override_reserve_records_website).and_return(false)
        end

        it 'leaves the tracked item status as NEEDED_FROM_YOU' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 2,
                                 'displayName')).to eq('RV1 - Reserve Records Request')
          # Do not modify the cassette value
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 2, 'status')).to eq('NEEDED_FROM_YOU')
        end
      end

      context 'when :cst_suppress_evidence_requests_website is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(true)
        end

        it 'excludes Attorney Fees, Secondary Action Required, and Stage 2 Development tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'attributes', 'trackedItems').size).to eq(13)
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 0,
                                 'displayName')).to eq('Private Medical Record')
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 1,
                                 'displayName')).to eq('Submit buddy statement(s)')
        end
      end

      context 'when :cst_suppress_evidence_requests_website is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_suppress_evidence_requests_website).and_return(false)
        end

        it 'includes Attorney Fees, Secondary Action Required, and Stage 2 Development tracked items' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          parsed_body = JSON.parse(response.body)
          expect(parsed_body.dig('data', 'attributes', 'trackedItems').size).to eq(14)
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 0,
                                 'displayName')).to eq('Private Medical Record')
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 1,
                                 'displayName')).to eq('Submit buddy statement(s)')
          expect(parsed_body.dig('data', 'attributes', 'trackedItems', 2, 'displayName')).to eq('Attorney Fees')
        end
      end

      context 'when :cst_friendly_evidence_requests is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_friendly_evidence_requests).and_return(false)
        end

        it 'does not modify the claim data and leaves the less-readable data as-is' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          tracked_items = JSON.parse(response.body)['data']['attributes']['trackedItems']
          can_upload_values = tracked_items.map { |i| i['canUploadFile'] }
          expect(can_upload_values).to eq([nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil])
          friendly_name_values = tracked_items.map { |i| i['friendlyName'] }
          expect(friendly_name_values).to eq([nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil])
          activity_description_values = tracked_items.map { |i| i['activityDescription'] }
          expect(activity_description_values).to eq([nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil])
          short_description_values = tracked_items.map { |i| i['shortDescription'] }
          expect(short_description_values).to eq([nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil])
          support_alias_values = tracked_items.map { |i| i['supportAliases'] }
          expect(support_alias_values).to eq([nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil])
        end
      end

      context 'when :cst_friendly_evidence_requests is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_friendly_evidence_requests).and_return(true)
        end

        it 'modifies the claim data to include additional, human-readable fields' do
          VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
            get(:show, params: { id: '600383363' })
          end
          tracked_items = JSON.parse(response.body)['data']['attributes']['trackedItems']
          can_upload_values = tracked_items.map { |i| i['canUploadFile'] }
          expect(can_upload_values).to eq([true, true, true, true, true, true, false, true, true, true, true, true,
                                           true])
          friendly_name_values = tracked_items.map { |i| i['friendlyName'] }
          expect(friendly_name_values).to include('Authorization to disclose information')
          expect(friendly_name_values).to include('Proof of service')
          expect(friendly_name_values).to include('Employment information')
          expect(friendly_name_values).to include('Direct deposit information')
          expect(friendly_name_values).to include('Details about cause of PTSD')
          expect(friendly_name_values).to include('Reserve records')
          expect(friendly_name_values).to include('Proof of Service')
          expect(friendly_name_values).to include('Non-VA medical records')
          expect(friendly_name_values).to include('Disability exam for hearing')
          expect(friendly_name_values).to include('Mental health exam')
          activity_description_values = tracked_items.map { |i| i['activityDescription'] }
          expect(activity_description_values).to include('We need your permission to request your personal' \
                                                         ' information from a non-VA source, like a private' \
                                                         ' doctor or hospital.')
          expect(activity_description_values).to include('We\'ve requested your Proof of Service on your behalf.' \
                                                         ' No action is needed.')
          expect(activity_description_values).to include('We need employment information from your most' \
                                                         ' recent employer.')
          expect(activity_description_values).to include('We need your direct deposit information in' \
                                                         ' order to pay benefits, if awarded.')
          expect(activity_description_values).to include('We need information about the cause of' \
                                                         ' your posttraumatic stress disorder (PTSD).')
          expect(activity_description_values).to include('We\'ve requested your reserve records on' \
                                                         ' your behalf. No action is needed.')
          expect(activity_description_values).to include('We\'ve requested your proof of service on' \
                                                         ' your behalf. No action is needed.')
          expect(activity_description_values).to include('We\'ve requested your non-VA medical records on' \
                                                         ' your behalf. No action is needed.')
          expect(activity_description_values).to include('We\'ve requested a disability exam for your hearing.' \
                                                         ' The examiner\'s office will contact you to schedule' \
                                                         ' this appointment.')
          expect(activity_description_values).to include('We\'ve requested a mental health exam for you.' \
                                                         ' The examiner\'s office will contact you to schedule' \
                                                         ' this appointment.')
          short_description_values = tracked_items.map { |i| i['shortDescription'] }
          expect(short_description_values).to include('For your benefits claim, we\'ve requested your service' \
                                                      ' records or treatment records from your reserve unit.')
          expect(short_description_values).to include('For your benefits claim, we\'ve requested all your' \
                                                      ' DD Form 214\'s or other separation papers for all' \
                                                      ' your periods of military service.')
          support_alias_values = tracked_items.map { |i| i['supportAliases'] }
          expect(support_alias_values).to include(['VA Form 21-4142'])
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
      end

      context 'when :cst_show_document_upload_status is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).and_call_original
          allow(Flipper).to receive(:enabled?).with(:cst_show_document_upload_status).and_return(false)
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
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:cst_show_document_upload_status).and_return(true)
            create(:bd_lh_evidence_submission_success, claim_id:)
          end

          it 'shows the evidenceSubmissions section in claim attributes' do
            VCR.use_cassette('lighthouse/benefits_claims/show/200_response') do
              get(:show, params: { id: claim_id })
            end
            parsed_body = JSON.parse(response.body)
            expect(parsed_body.dig('data', 'attributes', 'evidenceSubmissions').size).to eq(1)
          end
        end

        context 'when record has a tracked item' do
          let(:tracked_item_id) { 394_443 }

          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:cst_show_document_upload_status).and_return(true)
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
                  tracked_item_type: 'Private Medical Record',
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
end
