# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::UnsuccessfulReportMailer, type: [:mailer] do
  let(:unsuccessful_claims_submissions) do
    FactoryBot.create(:auto_established_claim, :status_errored)
    ClaimsApi::AutoEstablishedClaim.where(status: 'errored')
                                   .order(:source, :status)
                                   .pluck(:source, :status, :id).map do |source, status, id|
                                     { id: id, status: status, source: source }
                                   end
  end
  let(:uploaded_upload) do
    FactoryBot.create(:auto_established_claim, :status_established)
    ClaimsApi::AutoEstablishedClaim.where(status: 'established')
                                   .order(:source, :status)
                                   .pluck(:source, :status, :id).map do |source, status, id|
                                     { id: id, status: status, source: source }
                                   end
  end
  let(:totals) do
    [
      {
        'vetraspec' => {
          'errored' => 1,
          'pending' => 4,
          'uploaded' => 1,
          :totals => 7,
          :error_rate => '14%',
          :expired_rate => '14%'
        }
      },
      {
        'vetpro' => {
          'errored' => 2,
          'pending' => 2,
          'uploaded' => 2,
          :totals => 7,
          :error_rate => '29%'
        }
      }
    ]
  end
  let(:statistics) do
    [
      { code: 'POW', count: 1, percentage: '50.0%' },
      { code: 'Homeless', count: 1, percentage: '50.0%' },
      { code: 'Terminally Ill', count: 1, percentage: '50.0%' }
    ]
  end

  describe '#build' do
    subject do
      described_class.build(7.days.ago, Time.zone.now, consumer_claims_totals: totals,
                                                       unsuccessful_claims_submissions: unsuccessful_claims_submissions,
                                                       grouped_claims_errors: statistics,
                                                       grouped_claims_warnings: statistics,
                                                       pending_claims_submissions: uploaded_upload,
                                                       flash_statistics: statistics,
                                                       special_issues_statistics: statistics,
                                                       poa_totals: { total: 0 },
                                                       unsuccessful_poa_submissions: []).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Daily Submission Report')
    end

    it 'sends to the right people' do
      expect(subject.to).to eq(
        %w[
          kayla.watanabe@adhocteam.us
          dan.hinze@adhocteam.us
          jeff.wallace@oddball.io
        ]
      )
    end
  end
end
