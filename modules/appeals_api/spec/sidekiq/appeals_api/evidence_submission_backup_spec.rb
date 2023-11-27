# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'support', 'shared_examples_for_monitored_worker.rb')

describe AppealsApi::EvidenceSubmissionBackup, type: :job do
  subject { described_class.new }

  let(:evidence_submission_appeal_success) do
    create(:evidence_submission,
           supportable: create(:supplemental_claim, status: 'success'),
           upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))
  end

  let(:evidence_submission_appeal_complete) do
    create(:evidence_submission,
           supportable: create(:notice_of_disagreement, status: 'complete'),
           upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))
  end

  it_behaves_like 'a monitored worker'

  # rubocop:disable RSpec/SubjectStub
  describe '#perform' do
    before do
      allow(subject).to receive(:evidence_to_submit).and_return(
        [
          evidence_submission_appeal_success,
          evidence_submission_appeal_complete
        ]
      )
      allow(evidence_submission_appeal_success).to receive(:submit_to_central_mail!)
      allow(evidence_submission_appeal_complete).to receive(:submit_to_central_mail!)
    end

    context 'when the delay evidence feature is enabled' do
      before { Flipper.enable(:decision_review_delay_evidence) }

      it 'calls "#submits_to_central_mail!" for each evidence record returned from #evidence_to_submit' do
        subject.perform

        expect(evidence_submission_appeal_success).to have_received(:submit_to_central_mail!)
        expect(evidence_submission_appeal_complete).to have_received(:submit_to_central_mail!)
      end
    end

    context 'when the delay evidence feature is disabled' do
      before { Flipper.disable(:decision_review_delay_evidence) }

      it 'does not take any action' do
        subject.perform

        expect(subject).not_to have_received(:evidence_to_submit)
        expect(evidence_submission_appeal_success).not_to have_received(:submit_to_central_mail!)
        expect(evidence_submission_appeal_complete).not_to have_received(:submit_to_central_mail!)
      end
    end
  end
  # rubocop:enable RSpec/SubjectStub

  describe '#evidence_to_submit' do
    it 'returns evidence in "uploaded" status when appeal is in "success" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:supplemental_claim, status: 'success'),
                        upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit).to include(evidence)
    end

    it 'returns evidence in "uploaded" status when appeal is in "complete" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:notice_of_disagreement, status: 'complete'),
                        upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit).to include(evidence)
    end

    it 'returns evidence in "uploaded" status when appeal is in "error" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:supplemental_claim, status: 'error'),
                        upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit).to include(evidence)
    end

    it 'does not return evidence when evidence not in "uploaded" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:notice_of_disagreement, status: 'success'),
                        upload_submission: create(:upload_submission, status: 'received', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit).not_to include(evidence)
    end

    it 'does not return evidence in "uploaded" status when appeal is still in "submitted" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:supplemental_claim, status: 'submitted'),
                        upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit).not_to include(evidence)
    end
  end
end
