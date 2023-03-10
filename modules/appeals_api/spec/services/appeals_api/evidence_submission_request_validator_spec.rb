# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::EvidenceSubmissionRequestValidator do
  describe '#call' do
    context 'Notice of Disagreement' do
      it 'returns an error if the NOD does not exist' do
        result = described_class.new(
          'fake_id', 'irrelevant_ssn', 'NoticeOfDisagreement'
        ).call

        expect(result).to eq([
                               :error,
                               { title: 'not_found',
                                 detail: 'NoticeOfDisagreement with uuid fake_id not found',
                                 code: '404',
                                 status: '404' }
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
                                 detail: 'This evidence submission is outside the 90 day legal window ' \
                                         'for submission.',
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

      context 'when ssn provided and mismatched' do
        it 'returns an error' do
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
      end

      context 'when file number provided and mismatched' do
        it 'returns an error' do
          notice_of_disagreement_v2 = create(:notice_of_disagreement_v2, :board_review_evidence_submission)

          result = described_class.new(
            notice_of_disagreement_v2.id, 'fake_ssn', 'NoticeOfDisagreement'
          ).call

          error = [:error,
                   { title: 'unprocessable_entity',
                     detail: "Request header 'X-VA-File-Number' does not match the associated appeal's file number",
                     code: 'DecisionReviewMismatchedFileNumber',
                     status: '422' }]

          expect(result).to eq(error)
        end
      end

      it 'returns :ok if the evidence is a-OK' do
        notice_of_disagreement = create(:notice_of_disagreement, board_review_option: 'evidence_submission')

        result = described_class.new(
          notice_of_disagreement.id, notice_of_disagreement.auth_headers['X-VA-SSN'], 'NoticeOfDisagreement'
        ).call

        expect(result).to eq([:ok, {}])
      end
    end

    context 'Supplemental Claim' do
      let(:supplemental_claim) { create(:supplemental_claim) }

      it 'returns an error if the SC does not exist' do
        result = described_class.new(
          'fake_id', 'irrelevant_ssn', 'SupplementalClaim'
        ).call

        expect(result).to eq([
                               :error,
                               { title: 'not_found',
                                 detail: 'SupplementalClaim with uuid fake_id not found',
                                 code: '404',
                                 status: '404' }
                             ])
      end

      it 'returns an error if the SC was submitted more than 7 days prior' do
        create(:status_update,
               to: 'submitted',
               status_update_time: 7.days.ago,
               statusable: supplemental_claim)

        result = described_class.new(
          supplemental_claim.id, 'irrelevant_ssn', 'SupplementalClaim'
        ).call

        expect(result).to eq([
                               :error,
                               {
                                 title: 'unprocessable_entity',
                                 detail: 'This submission is outside of the 7-day window for evidence submission',
                                 code: 'OutsideSubmissionWindow',
                                 status: '422'
                               }
                             ])
      end

      it 'returns with :ok if the SC was submitted less than 7 days prior' do
        create(:status_update,
               to: 'submitted',
               status_update_time: 5.days.ago,
               statusable: supplemental_claim)

        result = described_class.new(
          supplemental_claim.id, supplemental_claim.auth_headers['X-VA-SSN'], 'SupplementalClaim'
        ).call

        expect(result).to eq([:ok, {}])
      end

      it 'returns an error if the veteran ISNT REAL' do
        result = described_class.new(
          supplemental_claim.id, 'fake_ssn', 'SupplementalClaim'
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
        result = described_class.new(
          supplemental_claim.id, supplemental_claim.auth_headers['X-VA-SSN'], 'SupplementalClaim'
        ).call

        expect(result).to eq([:ok, {}])
      end
    end
  end
end
