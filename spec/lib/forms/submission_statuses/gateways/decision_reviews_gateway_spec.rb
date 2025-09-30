# frozen_string_literal: true

require 'rails_helper'
require 'forms/submission_statuses/gateways/decision_reviews_gateway'

describe Forms::SubmissionStatuses::Gateways::DecisionReviewsGateway,
         feature: :form_submission,
         team_owner: :vfs_authenticated_experience_backend do
  subject { described_class.new(user_account:, allowed_forms:) }

  let(:user_account) { create(:user_account) }
  let(:allowed_forms) { %w[20-0995 20-0996] }
  let(:decision_review_service) { instance_double(DecisionReviews::V1::Service) }

  before do
    allow(DecisionReviews::V1::Service).to receive(:new).and_return(decision_review_service)
  end

  describe '#data' do
    it 'returns a dataset with submissions and intake statuses' do
      # Mock the submissions query to return empty array
      appeal_query_mock = double
      allow(appeal_query_mock).to receive(:where).with(type_of_appeal: %w[SC HLR NOD]).and_return(double(pluck: []))
      allow(AppealSubmission).to receive(:where).with(user_account: user_account).and_return(appeal_query_mock)
      
      # Mock the SavedClaim query chain
      saved_claim_query_mock = double
      allow(saved_claim_query_mock).to receive(:where).and_return(saved_claim_query_mock)
      allow(saved_claim_query_mock).to receive(:order).and_return([])
      allow(SavedClaim).to receive(:where).and_return(saved_claim_query_mock)

      result = subject.data

      expect(result).to be_a(Forms::SubmissionStatuses::Dataset)
    end
  end

  describe '#submissions' do
    context 'with current user submissions' do
      let(:allowed_forms) { %w[20-0995 20-0996 10182] } # Include all Decision Reviews forms

      before do
        # Create SavedClaims (without user_account since it's ignored)
        sc_claim = create(:saved_claim_supplemental_claim)
        hlr_claim = create(:saved_claim_higher_level_review)
        nod_claim = create(:saved_claim_notice_of_disagreement)

        # Create AppealSubmissions linking user_account to SavedClaims
        appeal_submission1 = create(:appeal_submission, user_account:,
                                                        submitted_appeal_uuid: sc_claim.guid, type_of_appeal: 'SC')
        create(:appeal_submission, user_account:,
                                   submitted_appeal_uuid: hlr_claim.guid, type_of_appeal: 'HLR')
        create(:appeal_submission, user_account:,
                                   submitted_appeal_uuid: nod_claim.guid, type_of_appeal: 'NOD')

        # Create SecondaryAppealForm (21-4142)
        create(:secondary_appeal_form4142, appeal_submission: appeal_submission1)

        # Create submissions for other users that should be excluded
        other_user = create(:user_account)
        other_claim = create(:saved_claim_supplemental_claim)
        create(:appeal_submission, user_account: other_user,
                                   submitted_appeal_uuid: other_claim.guid, type_of_appeal: 'SC')
      end

      it 'returns only submissions for the current user' do
        submissions = subject.submissions
        expect(submissions.size).to eq(3) # 3 SavedClaims only

        # Should only include SavedClaim objects (SecondaryAppealForms handled in api_statuses)
        expect(submissions).to all(be_a(SavedClaim))

        # Verify the SavedClaim submissions are the right ones by checking their guids match appeal submissions
        user_appeal_uuids = AppealSubmission.where(user_account:).pluck(:submitted_appeal_uuid)
        saved_claim_guids = submissions.map(&:guid)
        expect(saved_claim_guids).to match_array(user_appeal_uuids)
      end

      it 'includes all Decision Reviews form types' do
        submissions = subject.submissions
        class_names = submissions.map(&:class).map(&:name)
        expect(class_names).to include('SavedClaim::SupplementalClaim')
        expect(class_names).to include('SavedClaim::HigherLevelReview')
        expect(class_names).to include('SavedClaim::NoticeOfDisagreement')
        # SecondaryAppealForms are not included in submissions but handled via associations in api_statuses
      end

      it 'excludes records with delete_date' do
        deleted_claim = create(:saved_claim_supplemental_claim, delete_date: 1.day.ago)
        create(:appeal_submission, user_account:,
                                   submitted_appeal_uuid: deleted_claim.guid, type_of_appeal: 'SC')

        submissions = subject.submissions
        expect(submissions.map(&:id)).not_to include(deleted_claim.id)
      end
    end

    context 'with allowed forms filter' do
      let(:allowed_forms) { %w[20-0995] }

      before do
        # Create SavedClaims
        sc_claim = create(:saved_claim_supplemental_claim)
        hlr_claim = create(:saved_claim_higher_level_review)

        # Create AppealSubmissions linking user_account to SavedClaims
        create(:appeal_submission, user_account:,
                                   submitted_appeal_uuid: sc_claim.guid, type_of_appeal: 'SC')
        create(:appeal_submission, user_account:,
                                   submitted_appeal_uuid: hlr_claim.guid, type_of_appeal: 'HLR')
      end

      it 'returns only submissions for allowed forms' do
        submissions = subject.submissions
        expect(submissions).to all(be_a(SavedClaim::SupplementalClaim))
        expect(submissions.size).to eq(1)
      end
    end
  end

  describe '#api_statuses' do
    let(:sc_claim) { create(:saved_claim_supplemental_claim) }
    let(:hlr_claim) { create(:saved_claim_higher_level_review) }
    let(:nod_claim) { create(:saved_claim_notice_of_disagreement) }

    context 'with Supplemental Claim' do
      let(:submissions) { [sc_claim] }
      let(:api_response) do
        {
          'data' => {
            'attributes' => {
              'status' => 'complete',
              'detail' => 'Claim processed successfully',
              'updatedAt' => '2024-01-01T10:00:00.000Z'
            }
          }
        }
      end

      before do
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))
      end

      it 'calls get_supplemental_claim and returns normalized status data' do
        statuses_data, errors = subject.api_statuses(submissions)

        expect(decision_review_service).to have_received(:get_supplemental_claim).with(sc_claim.guid)
        expect(errors).to be_nil
        expect(statuses_data.size).to eq(1)

        status = statuses_data.first
        expect(status['attributes']['guid']).to eq(sc_claim.guid)
        expect(status['attributes']['status']).to eq('received') # normalized from 'complete'
        expect(status['attributes']['message']).to eq('received') # normalized message
        expect(status['attributes']['detail']).to eq('Claim processed successfully')
      end
    end

    context 'with Higher Level Review' do
      let(:submissions) { [hlr_claim] }
      let(:api_response) do
        {
          'data' => {
            'attributes' => {
              'status' => 'processing',
              'detail' => 'Review in progress',
              'updatedAt' => '2024-01-02T10:00:00.000Z'
            }
          }
        }
      end

      before do
        allow(decision_review_service).to receive(:get_higher_level_review)
          .with(hlr_claim.guid).and_return(double(body: api_response))
      end

      it 'calls get_higher_level_review and returns normalized status data' do
        statuses_data, errors = subject.api_statuses(submissions)

        expect(decision_review_service).to have_received(:get_higher_level_review).with(hlr_claim.guid)
        expect(errors).to be_nil
        expect(statuses_data.size).to eq(1)

        status = statuses_data.first
        expect(status['attributes']['status']).to eq('inProgress') # normalized from 'processing'
        expect(status['attributes']['message']).to eq('inProgress') # normalized message
      end
    end

    context 'with Notice of Disagreement' do
      let(:submissions) { [nod_claim] }
      let(:api_response) do
        {
          'data' => {
            'attributes' => {
              'status' => 'submitted',
              'detail' => 'NOD submitted',
              'updatedAt' => '2024-01-03T10:00:00.000Z'
            }
          }
        }
      end

      before do
        allow(decision_review_service).to receive(:get_notice_of_disagreement)
          .with(nod_claim.guid).and_return(double(body: api_response))
      end

      it 'calls get_notice_of_disagreement and returns normalized status data' do
        statuses_data, errors = subject.api_statuses(submissions)

        expect(decision_review_service).to have_received(:get_notice_of_disagreement).with(nod_claim.guid)
        expect(errors).to be_nil
        expect(statuses_data.size).to eq(1)

        status = statuses_data.first
        expect(status['attributes']['status']).to eq('inProgress') # normalized from 'submitted'
        expect(status['attributes']['message']).to eq('inProgress') # normalized message
      end
    end

    context 'when API returns 404' do
      let(:submissions) { [sc_claim] }

      before do
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid)
          .and_raise(DecisionReviews::V1::ServiceException.new(key: 'DR_404', original_status: 404))
      end

      it 'handles not found gracefully with expired status' do
        statuses_data, errors = subject.api_statuses(submissions)

        expect(errors).to be_nil
        expect(statuses_data.size).to eq(1)

        status = statuses_data.first
        expect(status['attributes']['status']).to eq('expired') # normalized for not found
        expect(status['attributes']['message']).to eq('expired')
        expect(status['attributes']['detail']).to eq('Submission not found in Decision Reviews system')
        expect(status['attributes']['updated_at']).to be_nil
      end
    end

    context 'with SupplementalClaim having Secondary Appeal Form (21-4142)' do
      let(:sc_with_secondary) { create(:saved_claim_supplemental_claim) }
      let(:appeal_submission) do
        create(:appeal_submission, user_account:,
                                   submitted_appeal_uuid: sc_with_secondary.guid, type_of_appeal: 'SC')
      end
      let(:secondary_form) { create(:secondary_appeal_form4142, appeal_submission:) }
      let(:submissions) { [sc_with_secondary] }
      let(:allowed_forms) { %w[20-0995 form0995_form4142] }

      let(:dr_api_response) do
        {
          'data' => {
            'attributes' => {
              'status' => 'complete',
              'detail' => 'SC processed',
              'updatedAt' => '2024-01-01T10:00:00.000Z'
            }
          }
        }
      end

      let(:bi_api_response) do
        {
          'data' => {
            'attributes' => {
              'status' => 'vbms',
              'detail' => 'Form processed by VBMS',
              'updated_at' => '2024-01-04T10:00:00.000Z'
            }
          }
        }
      end

      let(:benefits_intake_service) { instance_double(BenefitsIntake::Service) }

      before do
        # Set up the association
        secondary_form # Trigger creation

        # Mock Decision Reviews API for SupplementalClaim
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_with_secondary.guid).and_return(double(body: dr_api_response))

        # Mock Benefits Intake API for SecondaryAppealForm
        allow(BenefitsIntake::Service).to receive(:new).and_return(benefits_intake_service)
        allow(benefits_intake_service).to receive(:get_status)
          .with(uuid: secondary_form.guid).and_return(double(body: bi_api_response))
      end

      it 'calls both Decision Reviews and Benefits Intake APIs' do
        statuses_data, errors = subject.api_statuses(submissions)

        expect(decision_review_service).to have_received(:get_supplemental_claim).with(sc_with_secondary.guid)
        expect(benefits_intake_service).to have_received(:get_status).with(uuid: secondary_form.guid)
        expect(errors).to be_nil
        expect(statuses_data.size).to eq(2) # One for SC, one for secondary form

        # Check primary form status (normalized)
        primary_status = statuses_data.find { |s| s['attributes']['guid'] == sc_with_secondary.guid }
        expect(primary_status['attributes']['status']).to eq('received') # normalized from 'complete'
        expect(primary_status['attributes']['message']).to eq('received')

        # Check secondary form status (Benefits Intake - not normalized)
        secondary_status = statuses_data.find { |s| s['attributes']['guid'] == secondary_form.guid }
        expect(secondary_status['attributes']['status']).to eq('vbms') # Benefits Intake status not normalized
        expect(secondary_status['attributes']['message']).to eq('vbms')
        expect(secondary_status['attributes']['form_type']).to eq('form0995_form4142')
      end
    end

    context 'when API call fails with other error' do
      let(:submissions) { [sc_claim] }

      before do
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid)
          .and_raise(DecisionReviews::V1::ServiceException.new(key: 'SERVER_ERROR', original_status: 500))
      end

      it 'returns errors' do
        statuses_data, errors = subject.api_statuses(submissions)

        expect(statuses_data.size).to eq(0)
        expect(errors).not_to be_empty
      end
    end

    context 'status normalization behavior' do
      let(:submissions) { [sc_claim] }

      it 'normalizes "pending" status to "inProgress"' do
        api_response = build_api_response(status: 'pending')
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('inProgress')
        expect(statuses_data.first['attributes']['message']).to eq('inProgress')
      end

      it 'normalizes "submitting" status to "inProgress"' do
        api_response = build_api_response(status: 'submitting')
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('inProgress')
      end

      it 'normalizes "processing" status to "inProgress"' do
        api_response = build_api_response(status: 'processing')
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('inProgress')
      end

      it 'normalizes "submitted" status to "inProgress"' do
        api_response = build_api_response(status: 'submitted')
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('inProgress')
      end

      it 'normalizes "success" status to "inProgress"' do
        api_response = build_api_response(status: 'success')
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('inProgress')
      end

      it 'normalizes "complete" status to "received"' do
        api_response = build_api_response(status: 'complete')
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('received')
      end

      it 'normalizes "error" status to "expired"' do
        api_response = build_api_response(status: 'error')
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('expired')
      end

      it 'normalizes unknown status to "expired"' do
        api_response = build_api_response(status: 'unknown_status')
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('expired')
      end

      it 'handles nil status by returning "expired"' do
        api_response = build_api_response(status: nil)
        allow(decision_review_service).to receive(:get_supplemental_claim)
          .with(sc_claim.guid).and_return(double(body: api_response))

        statuses_data, = subject.api_statuses(submissions)

        expect(statuses_data.first['attributes']['status']).to eq('expired')
      end

      it 'maps all in-progress statuses correctly' do
        in_progress_statuses = %w[pending submitting processing submitted success]

        in_progress_statuses.each do |status|
          api_response = build_api_response(status:)
          allow(decision_review_service).to receive(:get_supplemental_claim)
            .with(sc_claim.guid).and_return(double(body: api_response))

          statuses_data, = subject.api_statuses(submissions)

          expect(statuses_data.first['attributes']['status']).to eq('inProgress')
        end
      end

      it 'maps error-like statuses to expired' do
        error_statuses = %w[error failed rejected invalid]

        error_statuses.each do |status|
          api_response = build_api_response(status:)
          allow(decision_review_service).to receive(:get_supplemental_claim)
            .with(sc_claim.guid).and_return(double(body: api_response))

          statuses_data, = subject.api_statuses(submissions)

          expect(statuses_data.first['attributes']['status']).to eq('expired')
        end
      end
    end
  end

  private

  def build_api_response(status:)
    {
      'data' => {
        'attributes' => {
          'status' => status,
          'detail' => 'Sample detail',
          'updatedAt' => '2023-01-01T12:00:00Z'
        }
      }
    }
  end
end
