# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::ReportUnsuccessfulSubmissions, type: :job do
  subject { described_class.new }

  let(:expired_hash) do
    { guid: '8ef145ee-3c6a-4215-b39a-af56c0d2c347', status: 'expired', consumer_name: 'test consumer' }
  end
  let(:error_upload) { create(:upload_submission, :status_error, consumer_name: 'test consumer') }
  let(:expired) { create(:upload_submission, expired_hash) }
  let(:upload) { create(:upload_submission, :status_uploaded, consumer_name: 'test consumer') }

  describe '#perform' do
    it 'sends mail', skip: 'Unknown reason for skip' do
      with_settings(Settings.vba_documents,
                    report_enabled: true) do
        Timecop.freeze
        to = Time.zone.now
        from = to.monday? ? 7.days.ago : 1.day.ago
        expect(VBADocuments::UnsuccessfulReportMailer).to receive(:build).once.with(
          send_mail_totals,
          VBADocuments::UploadSubmission.where(
            created_at: from..to,
            status: 'uploaded'
          ).order(:consumer_name, :status),
          VBADocuments::UploadSubmission.where(
            created_at: from..to,
            status: %w[error expired]
          ).order(:consumer_name, :status),
          from,
          to
        ).and_return(double.tap do |mailer|
                       expect(mailer).to receive(:deliver_now).once
                     end)
        described_class.new.perform
        Timecop.return
      end
    end

    it 'calculate totals', skip: 'Unknown reason for skip' do
      with_settings(Settings.vba_documents,
                    report_enabled: true) do
        error_upload
        upload
        expired

        job = described_class.new
        job.perform
        totals = job.totals

        expect(totals.keys.first).to eq('test consumer')
        expect(totals['test consumer'][:error_rate]).to eq('33%')
        expect(totals['test consumer'][:expired_rate]).to eq('33%')
      end
    end
  end

  describe '#stuck' do
    let(:stuck_submission) do
      create(:upload_submission, :status_uploaded,
             created_at: 3.hours.ago,
             consumer_name: 'test consumer')
    end

    let(:uploaded_submission_sc_evidence) do
      create(:upload_submission, :status_uploaded,
             created_at: 3.hours.ago,
             consumer_name: 'appeals_api_sc_evidence_submission')
    end

    let(:uploaded_submission_nod_evidence) do
      create(:upload_submission, :status_uploaded,
             created_at: 3.hours.ago,
             consumer_name: 'appeals_api_nod_evidence_submission')
    end

    before do
      @to = Time.zone.now
      @from = 1.day.ago
    end

    context 'when the :decision_review_delay_evidence feature is enabled' do
      before { Flipper.enable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'returns submissions in "uploaded" status' do
        expect(subject.stuck).to include(stuck_submission)
      end

      it 'does not return "uploaded" submissions that were submitted from the appeals api' do
        result = subject.stuck
        expect(result).not_to include(uploaded_submission_sc_evidence)
        expect(result).not_to include(uploaded_submission_nod_evidence)
      end
    end

    context 'when the :decision_review_delay_evidence feature is disabled' do
      before { Flipper.disable(:decision_review_delay_evidence) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

      it 'returns submissions in "uploaded" status' do
        expect(subject.stuck).to include(stuck_submission)
      end

      it 'returns "uploaded" submissions that were submitted from the appeals api' do
        result = subject.stuck
        expect(result).to include(uploaded_submission_sc_evidence)
        expect(result).to include(uploaded_submission_nod_evidence)
      end
    end
  end

  private

  def send_mail_totals
    {
      'summary' => {
        'pending' => 0,
        'uploaded' => 0,
        'received' => 0,
        'processing' => 0,
        'success' => 0,
        'vbms' => 0,
        'error' => 0,
        'expired' => 0,
        'total' => 0,
        'success_rate' => '0%',
        'error_rate' => '0%',
        'expired_rate' => '0%'
      }
    }
  end
end
