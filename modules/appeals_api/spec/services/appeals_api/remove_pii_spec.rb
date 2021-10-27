# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

module AppealsApi
  RSpec.describe RemovePii do
    describe '#run!' do
      it 'raises an ArgumentError if an invalid form type is supplied' do
        expect { RemovePii.new(form_type: 'Invalid').run! }.to raise_error(ArgumentError)
      end

      it 'removes PII from HLR records needing PII removal' do
        day_old_has_pii = create :higher_level_review, :completed_a_day_ago
        week_old_has_pii = create :higher_level_review, :completed_a_week_ago
        day_old_has_pii.update(updated_at: 1.day.ago)
        week_old_has_pii.update(updated_at: 8.days.ago)

        expect(day_old_has_pii.form_data_ciphertext).not_to be_nil
        expect(week_old_has_pii.form_data_ciphertext).not_to be_nil

        RemovePii.new(form_type: HigherLevelReview).run!

        expect(day_old_has_pii.reload.form_data_ciphertext).not_to be_nil
        expect(week_old_has_pii.reload.form_data_ciphertext).to be_nil
      end

      it 'removes PII from SC records needing PII removal' do
        day_old_has_pii = create :supplemental_claim, :completed_a_day_ago
        week_old_has_pii = create :supplemental_claim, :completed_a_week_ago
        day_old_has_pii.update(updated_at: 1.day.ago)
        week_old_has_pii.update(updated_at: 8.days.ago)

        expect(day_old_has_pii.form_data_ciphertext).not_to be_nil
        expect(week_old_has_pii.form_data_ciphertext).not_to be_nil

        RemovePii.new(form_type: SupplementalClaim).run!

        expect(day_old_has_pii.reload.form_data_ciphertext).not_to be_nil
        expect(week_old_has_pii.reload.form_data_ciphertext).to be_nil
      end

      describe 'removes PII from NODs at the correct times for the different lanes' do
        it 'evidence_submission' do
          week_old_has_pii = create :notice_of_disagreement, :completed_a_week_ago,
                                    board_review_option: 'evidence_submission'
          ninety_day_old_has_pii = create :notice_of_disagreement, :status_completed,
                                          updated_at: 90.days.ago, board_review_option: 'evidence_submission'
          ninety_two_day_old_has_pii = create :notice_of_disagreement, :status_completed,
                                              updated_at: 92.days.ago, board_review_option: 'evidence_submission'
          week_old_has_pii.update(updated_at: 7.days.ago)
          ninety_day_old_has_pii.update(updated_at: 90.days.ago)
          ninety_two_day_old_has_pii.update(updated_at: 92.days.ago)

          expect(week_old_has_pii.form_data_ciphertext).not_to be_nil
          expect(ninety_day_old_has_pii.form_data_ciphertext).not_to be_nil
          expect(ninety_two_day_old_has_pii.form_data_ciphertext).not_to be_nil

          RemovePii.new(form_type: NoticeOfDisagreement).run!

          expect(week_old_has_pii.reload.form_data_ciphertext).not_to be_nil
          expect(ninety_day_old_has_pii.reload.form_data_ciphertext).not_to be_nil
          expect(ninety_two_day_old_has_pii.reload.form_data_ciphertext).to be_nil
        end

        it 'direct_review' do
          one_day_old = create :notice_of_disagreement, :completed_a_day_ago, board_review_option: 'direct_review'
          week_old_has_pii = create :notice_of_disagreement, :completed_a_week_ago, board_review_option: 'direct_review'
          one_day_old.update(updated_at: 1.day.ago)
          week_old_has_pii.update(updated_at: 8.days.ago)

          expect(one_day_old.form_data_ciphertext).not_to be_nil
          expect(week_old_has_pii.form_data_ciphertext).not_to be_nil

          RemovePii.new(form_type: NoticeOfDisagreement).run!

          expect(one_day_old.reload.form_data_ciphertext).not_to be_nil
          expect(week_old_has_pii.reload.form_data_ciphertext).to be_nil
        end

        it 'hearing' do
          one_day_old = create :notice_of_disagreement, :completed_a_day_ago, board_review_option: 'hearing'
          week_old_has_pii = create :notice_of_disagreement, :completed_a_week_ago, board_review_option: 'hearing'
          one_day_old.update(updated_at: 1.day.ago)
          week_old_has_pii.update(updated_at: 8.days.ago)

          expect(one_day_old.form_data_ciphertext).not_to be_nil
          expect(week_old_has_pii.form_data_ciphertext).not_to be_nil

          RemovePii.new(form_type: NoticeOfDisagreement).run!

          expect(one_day_old.reload.form_data_ciphertext).not_to be_nil
          expect(week_old_has_pii.reload.form_data_ciphertext).to be_nil
        end
      end

      it 'sends a message to sentry if the removal failed.' do
        allow_any_instance_of(RemovePii).to receive(:records_were_not_cleared).and_return(true)
        service = RemovePii.new(form_type: NoticeOfDisagreement)
        expect(service).to receive(:log_failure_to_sentry)

        service.run!
      end
    end
  end
end
