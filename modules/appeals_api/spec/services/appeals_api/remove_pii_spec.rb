# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::RemovePii do
  describe '#run!' do
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
