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

  let(:evidence_submission_appeal_with_old_uploaded_status_updates) do
    create(:evidence_submission,
           supportable: create(:notice_of_disagreement, status: 'submitted'),
           upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))
  end
  let(:status_update_submitted) do
    create(:status_update,
           to: 'submitted',
           status_update_time: 92.days.ago,
           statusable: evidence_submission_appeal_with_old_uploaded_status_updates.supportable)
  end

  it_behaves_like 'a monitored worker'

  # rubocop:disable RSpec/SubjectStub
  describe '#perform' do
    before do
      allow(evidence_submission_appeal_success).to receive(:submit_to_central_mail!)
      allow(evidence_submission_appeal_complete).to receive(:submit_to_central_mail!)

      allow(subject).to receive_messages(evidence_to_submit_by_status: [
                                           evidence_submission_appeal_success,
                                           evidence_submission_appeal_complete
                                         ], evidence_to_submit_by_age: [
                                           evidence_submission_appeal_with_old_uploaded_status_updates
                                         ])
      allow(evidence_submission_appeal_with_old_uploaded_status_updates).to receive(:submit_to_central_mail!)
    end

    context 'when the delay evidence feature is enabled' do
      before { allow(Flipper).to receive(:enabled?).with(:decision_review_delay_evidence).and_return(true) }

      it 'calls "#submits_to_central_mail!" for each evidence record returned from #evidence_to_submit' do
        subject.perform

        expect(evidence_submission_appeal_success).to have_received(:submit_to_central_mail!)
        expect(evidence_submission_appeal_complete).to have_received(:submit_to_central_mail!)
        expect(evidence_submission_appeal_with_old_uploaded_status_updates).to have_received(:submit_to_central_mail!)
      end
    end

    context 'when the delay evidence feature is disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:decision_review_delay_evidence).and_return(false) }

      it 'does not take any action' do
        subject.perform

        expect(subject).not_to have_received(:evidence_to_submit_by_status)
        expect(evidence_submission_appeal_success).not_to have_received(:submit_to_central_mail!)
        expect(evidence_submission_appeal_complete).not_to have_received(:submit_to_central_mail!)
        expect(evidence_submission_appeal_with_old_uploaded_status_updates)
          .not_to have_received(:submit_to_central_mail!)
      end
    end
  end
  # rubocop:enable RSpec/SubjectStub

  describe '#evidence_to_submit_by_status' do
    it 'returns evidence in "uploaded" status when appeal is in "complete" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:notice_of_disagreement, status: 'complete'),
                        upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit_by_status).to include(evidence)
    end

    it 'returns evidence in "uploaded" status when appeal is in "error" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:supplemental_claim, status: 'error'),
                        upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit_by_status).to include(evidence)
    end

    it 'does not return evidence when evidence not in "uploaded" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:notice_of_disagreement, status: 'success'),
                        upload_submission: create(:upload_submission, status: 'received', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit_by_status).not_to include(evidence)
    end

    it 'does not returns evidence in "uploaded" status when appeal is in "success" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:supplemental_claim, status: 'success'),
                        upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit_by_status).not_to include(evidence)
    end

    it 'does not return evidence in "uploaded" status when appeal is still in "submitted" status' do
      evidence = create(:evidence_submission,
                        supportable: create(:supplemental_claim, status: 'submitted'),
                        upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))

      expect(subject.evidence_to_submit_by_status).not_to include(evidence)
    end
  end

  describe '#evidence_to_submit_by_age' do
    it 'returns evidence in "uploaded" status when appeal is in "submitted" status' do
      # appeal over 24 hours old so should be returned
      nod = create(:notice_of_disagreement, status: 'submitted')
      # status update record for appeal
      create(:status_update,
             to: 'submitted',
             status_update_time: 5.days.ago,
             statusable: nod)
      old_evidence1 = create(:evidence_submission,
                             supportable: nod,
                             upload_submission: create(:upload_submission,
                                                       status: 'uploaded',
                                                       guid: SecureRandom.uuid))
      old_evidence2 = create(:evidence_submission,
                             supportable: nod,
                             upload_submission: create(:upload_submission,
                                                       status: 'uploaded',
                                                       guid: SecureRandom.uuid))

      # appeal less than 24 hours old
      new_evidence = create(:evidence_submission,
                            supportable: create(:notice_of_disagreement, status: 'submitted'),
                            upload_submission: create(:upload_submission, status: 'uploaded', guid: SecureRandom.uuid))
      # corner case, two status records, should use the 'newest'(1 hour old one) for appeal
      # age calc, and since its only 1 hour old since submitted to CM, this evidence submission
      # should not be uploaded yet
      create(:status_update,
             to: 'submitted',
             status_update_time: 5.days.ago,
             statusable: new_evidence.supportable)
      create(:status_update,
             to: 'submitted',
             status_update_time: 1.hour.ago,
             statusable: new_evidence.supportable)

      # appeal older than 24 hours, no status update so uses created at timestamp to calc age
      old_evidence_no_submitted_status_update = create(:evidence_submission,
                                                       supportable: create(:notice_of_disagreement,
                                                                           status: 'submitted',
                                                                           created_at: 2.days.ago),
                                                       upload_submission: create(:upload_submission,
                                                                                 status: 'uploaded',
                                                                                 guid: SecureRandom.uuid))

      # appeal less than 24 hours old, no status update so uses created at timestamp to calc age
      new_evidence_no_submitted_status_update = create(:evidence_submission,
                                                       supportable: create(:notice_of_disagreement,
                                                                           status: 'submitted',
                                                                           created_at: 1.minute.ago),
                                                       upload_submission: create(:upload_submission,
                                                                                 status: 'uploaded',
                                                                                 guid: SecureRandom.uuid))
      expect(subject.evidence_to_submit_by_age).to include(old_evidence1)
      expect(subject.evidence_to_submit_by_age).to include(old_evidence2)
      expect(subject.evidence_to_submit_by_age).to include(old_evidence_no_submitted_status_update)

      expect(subject.evidence_to_submit_by_age).not_to include(new_evidence)
      expect(subject.evidence_to_submit_by_age).not_to include(new_evidence_no_submitted_status_update)
    end
  end
end
