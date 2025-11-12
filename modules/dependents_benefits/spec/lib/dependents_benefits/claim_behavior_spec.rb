# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/claim_behavior'

RSpec.describe DependentsBenefits::ClaimBehavior do
  before do
    allow(PdfFill::Filler).to receive(:fill_form).and_return('tmp/pdfs/mock_form_final.pdf')
  end

  let(:claim) { create(:dependents_claim) }
  let(:child_claim) { create(:add_remove_dependents_claim) }

  describe '#submissions_succeeded?' do
    context 'when BGS::Submission has an attempt with status == "submitted"' do
      it 'returns true' do
        submission = create(:bgs_submission, saved_claim_id: claim.id)
        create(:bgs_submission_attempt, submission:, status: 'submitted')

        expect(claim.submissions_succeeded?).to be true
      end
    end

    context 'when BGS::Submission has an attempt with status == "pending"' do
      it 'returns false' do
        submission = create(:bgs_submission, saved_claim_id: claim.id)
        create(:bgs_submission_attempt, submission:, status: 'pending')

        expect(claim.submissions_succeeded?).to be false
      end
    end

    context 'when BGS::Submission has no attempts' do
      it 'returns false' do
        create(:bgs_submission, saved_claim_id: claim.id)

        expect(claim.submissions_succeeded?).to be false
      end
    end

    context 'when there are no submissions for the claim' do
      it 'returns false' do
        expect(claim.submissions_succeeded?).to be false
      end
    end

    context 'when there are multiple submissions with mixed statuses' do
      it 'returns false if any submission has non-submitted attempts' do
        submission1 = create(:bgs_submission, saved_claim_id: claim.id)
        submission2 = create(:bgs_submission, saved_claim_id: claim.id)

        create(:bgs_submission_attempt, submission: submission1, status: 'submitted')
        create(:bgs_submission_attempt, submission: submission2, status: 'pending')

        expect(claim.submissions_succeeded?).to be false
      end

      it 'returns true if all submissions have submitted attempts' do
        submission1 = create(:bgs_submission, saved_claim_id: claim.id)
        submission2 = create(:bgs_submission, saved_claim_id: claim.id)

        create(:bgs_submission_attempt, submission: submission1, status: 'submitted')
        create(:bgs_submission_attempt, submission: submission2, status: 'submitted')

        expect(claim.submissions_succeeded?).to be true
      end
    end

    context 'when submission has multiple attempts' do
      it 'uses the latest attempt status' do
        submission = create(:bgs_submission, saved_claim_id: claim.id)

        # Create attempts in chronological order
        create(:bgs_submission_attempt, submission:, status: 'pending', created_at: 1.hour.ago)
        create(:bgs_submission_attempt, submission:, status: 'submitted', created_at: 30.minutes.ago)

        expect(claim.submissions_succeeded?).to be true
      end
    end
  end

  describe '#to_pdf' do
    it 'does not fail' do
      expect(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).with(child_claim, nil).and_call_original
      expect { child_claim.to_pdf }.not_to raise_error
    end

    context 'when veteran_information is missing' do
      before do
        allow(DependentsBenefits::PdfFill::Filler).to receive(:fill_form).and_call_original

        child_claim.parsed_form.delete('veteran_information')
        child_claim.parsed_form['dependents_application'].delete('veteran_information')
      end

      it 'raises an error in the PDF filler' do
        expect { child_claim.to_pdf }.to raise_error(DependentsBenefits::MissingVeteranInfoError)
      end
    end
  end

  describe '#folder_identifier' do
    context 'when ssn is present' do
      before do
        claim.parsed_form['veteran_information']['ssn'] = '123-45-6789'
        claim.parsed_form['veteran_information']['participant_id'] = nil
        claim.parsed_form['veteran_information']['icn'] = nil
      end

      it 'includes ssn in the folder identifier' do
        expect(claim.folder_identifier).to eq('VETERAN:SSN:123-45-6789')
      end
    end

    context 'when participant_id is present' do
      before do
        claim.parsed_form['veteran_information']['ssn'] = nil
        claim.parsed_form['veteran_information']['participant_id'] = 'P123456789'
        claim.parsed_form['veteran_information']['icn'] = nil
      end

      it 'includes participant_id in the folder identifier' do
        expect(claim.folder_identifier).to eq('VETERAN:PARTICIPANT_ID:P123456789')
      end
    end

    context 'when icn is present' do
      before do
        claim.parsed_form['veteran_information']['ssn'] = nil
        claim.parsed_form['veteran_information']['participant_id'] = nil
        claim.parsed_form['veteran_information']['icn'] = 'ICN123456789'
      end

      it 'includes icn in the folder identifier' do
        expect(claim.folder_identifier).to eq('VETERAN:ICN:ICN123456789')
      end
    end
  end
end
