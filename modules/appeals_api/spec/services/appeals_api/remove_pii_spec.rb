# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

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

  def create_appeals = [FactoryBot.create(v0_factory), FactoryBot.create(v2_factory)]

  def create_misc_appeals = create_appeals + misc_appeal_types.map { |f| FactoryBot.create(f) }

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
  describe '#run! with new PII rules' do
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
  end

  describe '#run!' do
    before { Flipper.disable :decision_review_updated_pii_rules }

    it 'raises an ArgumentError if an invalid form type is supplied' do
      expect { AppealsApi::RemovePii.new(form_type: 'Invalid').run! }.to raise_error(ArgumentError)
    end

    it 'removes PII from HLR records needing PII removal' do
      day_old_has_pii_v2 = create :higher_level_review_v2, status: 'complete'
      day_old_has_pii_v2.update updated_at: 1.day.ago

      week_old_has_pii_v2 = create :higher_level_review_v2, status: 'complete'
      week_old_has_pii_v2_incomplete = create :higher_level_review_v2, status: 'success' # Former V1 final status
      week_old_has_pii_v2_error = create :higher_level_review_v2, status: 'error'

      week_old_has_pii_v2.update updated_at: 8.days.ago
      week_old_has_pii_v2_incomplete.update updated_at: 8.days.ago
      week_old_has_pii_v2_error.update updated_at: 8.days.ago

      expect(day_old_has_pii_v2.form_data_ciphertext).to be_present
      expect(week_old_has_pii_v2.form_data_ciphertext).to be_present
      expect(week_old_has_pii_v2_incomplete.form_data_ciphertext).to be_present
      expect(week_old_has_pii_v2_error.form_data_ciphertext).to be_present

      AppealsApi::RemovePii.new(form_type: AppealsApi::HigherLevelReview).run!

      expect(day_old_has_pii_v2.reload.form_data_ciphertext).to be_present
      expect(week_old_has_pii_v2.reload.form_data_ciphertext).to be_nil
      expect(week_old_has_pii_v2_incomplete.reload.form_data_ciphertext).to be_present
      expect(week_old_has_pii_v2_error.reload.form_data_ciphertext).to be_present
    end

    it 'removes PII from SC records needing PII removal' do
      day_old_has_pii = create :supplemental_claim, status: 'complete'
      day_old_has_pii.update updated_at: 1.day.ago

      week_old_has_pii = create :supplemental_claim, status: 'complete'
      week_old_has_pii.update updated_at: 8.days.ago

      week_old_has_pii_error = create :supplemental_claim, status: 'error'
      week_old_has_pii_error.update updated_at: 8.days.ago

      expect(day_old_has_pii.form_data_ciphertext).to be_present
      expect(week_old_has_pii.form_data_ciphertext).to be_present
      expect(week_old_has_pii_error.form_data_ciphertext).to be_present

      AppealsApi::RemovePii.new(form_type: AppealsApi::SupplementalClaim).run!

      expect(day_old_has_pii.reload.form_data_ciphertext).to be_present
      expect(week_old_has_pii.reload.form_data_ciphertext).to be_nil
      expect(week_old_has_pii_error.reload.form_data_ciphertext).to be_present
    end

    describe 'removes PII from NODs at the correct times for the different lanes' do
      it 'evidence_submission' do
        week_old_has_pii = create :notice_of_disagreement, status: 'complete',
                                                           board_review_option: 'evidence_submission'
        ninety_day_old_has_pii = create :notice_of_disagreement, status: 'complete',
                                                                 board_review_option: 'evidence_submission'
        ninety_two_day_old_has_pii = create :notice_of_disagreement, status: 'complete',
                                                                     board_review_option: 'evidence_submission'
        ninety_two_day_old_has_pii_error = create :notice_of_disagreement, status: 'error',
                                                                           board_review_option: 'evidence_submission'
        week_old_has_pii.update(updated_at: 7.days.ago)
        ninety_day_old_has_pii.update(updated_at: 90.days.ago)
        ninety_two_day_old_has_pii.update(updated_at: 92.days.ago)
        ninety_two_day_old_has_pii_error.update(updated_at: 92.days.ago)

        expect(week_old_has_pii.form_data_ciphertext).to be_present
        expect(ninety_day_old_has_pii.form_data_ciphertext).to be_present
        expect(ninety_two_day_old_has_pii.form_data_ciphertext).to be_present
        expect(ninety_two_day_old_has_pii_error.form_data_ciphertext).to be_present

        AppealsApi::RemovePii.new(form_type: AppealsApi::NoticeOfDisagreement).run!

        expect(week_old_has_pii.reload.form_data_ciphertext).to be_present
        expect(ninety_day_old_has_pii.reload.form_data_ciphertext).to be_present
        expect(ninety_two_day_old_has_pii.reload.form_data_ciphertext).to be_nil
        expect(ninety_two_day_old_has_pii_error.reload.form_data_ciphertext).to be_present
      end

      it 'direct_review' do
        one_day_old = create :notice_of_disagreement, status: 'complete', board_review_option: 'direct_review'
        week_old_has_pii = create :notice_of_disagreement, status: 'complete', board_review_option: 'direct_review'
        week_old_has_pii_error = create :notice_of_disagreement, status: 'error', board_review_option: 'direct_review'
        one_day_old.update(updated_at: 1.day.ago)
        week_old_has_pii.update(updated_at: 8.days.ago)
        week_old_has_pii_error.update(updated_at: 8.days.ago)

        expect(one_day_old.form_data_ciphertext).to be_present
        expect(week_old_has_pii.form_data_ciphertext).to be_present
        expect(week_old_has_pii_error.form_data_ciphertext).to be_present

        AppealsApi::RemovePii.new(form_type: AppealsApi::NoticeOfDisagreement).run!

        expect(one_day_old.reload.form_data_ciphertext).to be_present
        expect(week_old_has_pii.reload.form_data_ciphertext).to be_nil
        expect(week_old_has_pii_error.reload.form_data_ciphertext).to be_present
      end

      it 'hearing' do
        one_day_old = create :notice_of_disagreement, status: 'complete', board_review_option: 'hearing'
        week_old_has_pii = create :notice_of_disagreement, status: 'complete', board_review_option: 'hearing'
        week_old_has_pii_error = create :notice_of_disagreement, status: 'error', board_review_option: 'hearing'
        one_day_old.update(updated_at: 1.day.ago)
        week_old_has_pii.update(updated_at: 8.days.ago)
        week_old_has_pii_error.update(updated_at: 8.days.ago)

        expect(one_day_old.form_data_ciphertext).to be_present
        expect(week_old_has_pii.form_data_ciphertext).to be_present
        expect(week_old_has_pii_error.form_data_ciphertext).to be_present

        AppealsApi::RemovePii.new(form_type: AppealsApi::NoticeOfDisagreement).run!

        expect(one_day_old.reload.form_data_ciphertext).to be_present
        expect(week_old_has_pii.reload.form_data_ciphertext).to be_nil
        expect(week_old_has_pii_error.reload.form_data_ciphertext).to be_present
      end
    end

    it 'sends a message to sentry if the removal failed.' do
      allow_any_instance_of(AppealsApi::RemovePii).to receive(:records_were_not_cleared).and_return(true)
      service = AppealsApi::RemovePii.new(form_type: AppealsApi::NoticeOfDisagreement)
      expect(service).to receive(:log_failure_to_sentry)

      service.run!
    end
  end
end
