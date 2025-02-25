# frozen_string_literal: true

require 'rails_helper'

def update_appeal_status(appeal, status, code: nil, detail: nil)
  # At the time of writing, the `update_status` method for each appeal model involves kicking off a sidekiq job to
  # create a matching StatusUpdate record. This is unwieldy in tests, so this method approximates the
  # `appeal.update_status!` method without involving sidekiq.
  appeal.update!(status:, code:, detail:)

  AppealsApi::StatusUpdate.create!(
    from: appeal.status,
    to: status,
    status_update_time: Time.zone.now,
    statusable_id: appeal.id,
    statusable_type: appeal.class.name,
    code:,
    detail:
  )

  appeal
end

shared_examples 'removes expired PII' do
  let(:now) { Time.zone.now }
  let(:code) { 'DOC202' }
  let(:detail) { "Upstream status: #{VBADocuments::UploadSubmission::ERROR_UNIDENTIFIED_MAIL}" }
  let(:misc_appeal_types) do
    %i[minimal_notice_of_disagreement extra_notice_of_disagreement_v2 extra_notice_of_disagreement_v0
       higher_level_review_v1 extra_higher_level_review_v2 minimal_higher_level_review_v0
       extra_supplemental_claim minimal_supplemental_claim_v0]
  end

  def create_appeals = [create(v0_factory), create(v2_factory)]

  def create_misc_appeals = create_appeals + misc_appeal_types.map { |f| create(f) }

  let!(:unexpired_appeals) do # These should all be ignored and remain unchanged
    appeals = []

    # These otherwise meet removal criteria (1, 2, 3) but are not old enough
    Timecop.freeze(now) do
      appeals += create_misc_appeals
      appeals += create_misc_appeals.map { |appeal| update_appeal_status(appeal, 'complete') }
      appeals += create_misc_appeals.map { |appeal| update_appeal_status(appeal, 'success') }
      appeals += create_misc_appeals.map { |appeal| update_appeal_status(appeal, 'error', code:, detail:) }
    end

    # These are old enough to meet removal criteria around status updates (1) but will be disqualified by having more
    # recent updates to the model
    oldest_appeals = []
    Timecop.freeze(now - 45.days) do
      oldest_appeals += create_misc_appeals.map { |appeal| update_appeal_status(appeal, 'processing') }
    end
    Timecop.freeze(now - 30.days) { oldest_appeals.map { |appeal| appeal.update(updated_at: Time.zone.now) } }
    appeals += oldest_appeals

    # These are old enough to meet removal criteria (2, 3), but...
    Timecop.freeze(now - 7.days) do
      appeals += create_misc_appeals # (2) they are not in a 'success' or 'complete' state
      appeals += create_misc_appeals.map do |appeal| # (3) they have an error other than "Unidentified Mail"
        update_appeal_status(appeal, 'error', code: 'DOC104', detail: 'Other error')
      end
    end

    appeals
  end

  let!(:expired_oldest_appeals) do
    Timecop.freeze(now - 45.days) do
      create_appeals + # These should be selected even though there are no status updates
        create_appeals.map { |appeal| update_appeal_status(appeal, 'submitted') }
    end
  end

  let!(:expired_errored_appeals) do
    Timecop.freeze(now - 7.days) do
      create_appeals.map { |appeal| update_appeal_status(appeal, 'error', code:, detail:) }
    end
  end

  let!(:expired_done_appeals) do
    Timecop.freeze(now - 7.days) do
      successes = create_appeals.map { |appeal| update_appeal_status(appeal, 'success') }
      completes = create_appeals.map { |appeal| update_appeal_status(appeal, 'complete') }
      successes + completes
    end
  end

  let(:expired_appeals) { expired_oldest_appeals + expired_errored_appeals + expired_done_appeals }

  before { AppealsApi::RemovePii.new(form_type:).run! }

  it 'does not remove unexpired PII' do
    unexpired_appeals.each do |appeal|
      appeal.reload
      expect(appeal.form_data).to be_present
      expect(appeal.auth_headers).to be_present if appeal.api_version == 'V2'
    end
  end

  it 'removes oldest expired PII' do
    expired_oldest_appeals.each do |appeal|
      appeal.reload
      expect(appeal.form_data).to be_blank
      expect(appeal.auth_headers).to be_blank
    end
  end

  it 'removes old complete/success PII' do
    expired_done_appeals.each do |appeal|
      appeal.reload
      expect(appeal.form_data).to be_blank
      expect(appeal.auth_headers).to be_blank
    end
  end

  it 'removes old Unidentified Mail errored PII' do
    expired_errored_appeals.each do |appeal|
      appeal.reload
      expect(appeal.form_data).to be_blank
      expect(appeal.auth_headers).to be_blank
    end
  end
end

describe AppealsApi::RemovePii do
  context 'with Higher-Level Review' do
    let(:v2_factory) { :higher_level_review_v2 }
    let(:v0_factory) { :higher_level_review_v0 }
    let(:form_type) { AppealsApi::HigherLevelReview }

    include_examples 'removes expired PII'
  end

  context 'with Supplemental Claim' do
    let(:v2_factory) { :supplemental_claim }
    let(:v0_factory) { :supplemental_claim_v0 }
    let(:form_type) { AppealsApi::SupplementalClaim }

    include_examples 'removes expired PII'
  end

  context 'with Notice of Disagreement' do
    let(:v2_factory) { :notice_of_disagreement_v2 }
    let(:v0_factory) { :notice_of_disagreement_v0 }
    let(:form_type) { AppealsApi::NoticeOfDisagreement }

    include_examples 'removes expired PII'
  end

  it 'raises an ArgumentError if an invalid form type is supplied' do
    expect { AppealsApi::RemovePii.new(form_type: 'Invalid').run! }.to raise_error(ArgumentError)
  end

  context 'when the removal fails' do
    let!(:appeals) do
      Timecop.freeze(100.days.ago) do
        status = 'complete'
        [create(:supplemental_claim, status:), create(:supplemental_claim_v0, status:)]
      end
    end

    before do
      instance = AppealsApi::RemovePii.new(form_type: AppealsApi::SupplementalClaim)
      msg = 'Failed to remove expired AppealsApi::SupplementalClaim PII from records'
      expect(Rails.logger).to receive(:error).with(msg, appeals.map(&:id))
      expect_any_instance_of(AppealsApi::Slack::Messager).to receive(:notify!)
      allow(instance).to receive(:remove_pii!).and_return []
      instance.run!
    end

    it 'logs an error and the IDs of records whose PII failed to be removed' do
      appeals.each do |appeal|
        appeal.reload
        expect(appeal.auth_headers).to be_present
        expect(appeal.form_data).to be_present
      end
    end
  end
end
