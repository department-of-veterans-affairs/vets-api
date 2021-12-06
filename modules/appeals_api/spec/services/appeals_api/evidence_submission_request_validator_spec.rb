# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  RSpec.describe EvidenceSubmissionRequestValidator do
    describe '#call' do
      it 'returns an error if the NOD does not exist' do
        result = described_class.new(
          'fake_id', 'irrelevant_ssn', 'NoticeOfDisagreement'
        ).call

        expect(result).to eq([
                               :error,
                               { title: 'not_found', detail: 'NoticeOfDisagreement with uuid fake_id not found.' }
                             ])
      end

      it 'returns an error if the NOD doesn\'t accept evidence' do
        notice_of_disagreement = create(:notice_of_disagreement, board_review_option: 'hearing')

        result = described_class.new(
          notice_of_disagreement.id, 'irrelevant_ssn', 'NoticeOfDisagreement'
        ).call

        expect(result).to eq([
                               :error,
                               {
                                 title: 'unprocessable_entity',
                                 detail: "Corresponding Notice of Disagreement 'boardReviewOption' " \
                                         "must be 'evidence_submission'",
                                 code: 'InvalidReviewOption',
                                 status: '422'
                               }
                             ])
      end

      it 'returns an error if the NOD was submitted more than 91 days prior' do
        notice_of_disagreement = create(:notice_of_disagreement, board_review_option: 'evidence_submission')
        create(:status_update,
               to: 'submitted',
               status_update_time: 92.days.ago,
               statusable: notice_of_disagreement)

        result = described_class.new(
          notice_of_disagreement.id, 'irrelevant_ssn', 'NoticeOfDisagreement'
        ).call

        expect(result).to eq([
                               :error,
                               {
                                 title: 'unprocessable_entity',
                                 detail: 'This evidence submission is outside the 90 day legal window for submission.',
                                 code: 'OutsideLegalWindow',
                                 status: '422'
                               }
                             ])
      end

      it 'returns with :ok if the NOD was submitted less than 90 days prior' do
        notice_of_disagreement = create(:notice_of_disagreement, board_review_option: 'evidence_submission')
        create(:status_update,
               to: 'submitted',
               status_update_time: 89.days.ago,
               statusable: notice_of_disagreement)

        result = described_class.new(
          notice_of_disagreement.id, notice_of_disagreement.auth_headers['X-VA-SSN'], 'NoticeOfDisagreement'
        ).call

        expect(result).to eq([:ok, {}])
      end

      it 'returns an error if the veteran ISNT REAL' do
        notice_of_disagreement = create(:notice_of_disagreement, board_review_option: 'evidence_submission')

        result = described_class.new(
          notice_of_disagreement.id, 'fake_ssn', 'NoticeOfDisagreement'
        ).call

        expect(result).to eq([
                               :error,
                               {
                                 title: 'unprocessable_entity',
                                 detail: "Request header 'X-VA-SSN' does not match the associated appeal's SSN",
                                 code: 'DecisionReviewMismatchedSSN',
                                 status: '422'
                               }
                             ])
      end

      it 'returns :ok if the evidence is a-OK' do
        notice_of_disagreement = create(:notice_of_disagreement, board_review_option: 'evidence_submission')

        result = described_class.new(
          notice_of_disagreement.id, notice_of_disagreement.auth_headers['X-VA-SSN'], 'NoticeOfDisagreement'
        ).call

        expect(result).to eq([:ok, {}])
      end
    end
  end
end
