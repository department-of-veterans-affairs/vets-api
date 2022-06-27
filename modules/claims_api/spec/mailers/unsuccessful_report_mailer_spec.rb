# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::UnsuccessfulReportMailer, type: [:mailer] do
  let(:unsuccessful_claims_submissions) do
    FactoryBot.create(:auto_established_claim, :status_errored)
    ClaimsApi::AutoEstablishedClaim.where(status: 'errored')
                                   .order(:source, :status)
                                   .pluck(:source, :created_at, :id).map do |source, created_at, id|
                                     { id: id, created_at: created_at, source: source }
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

  describe '#build' do
    subject do
      described_class.build(7.days.ago, Time.zone.now, consumer_claims_totals: totals,
                                                       unsuccessful_claims_submissions: unsuccessful_claims_submissions,
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
          jennica.stiehl@oddball.io
          jeff.wallace@oddball.io
          zachary.goldfine@va.gov
          david.mazik@va.gov
          premal.shah@va.gov
          emily.goodrich@oddball.io
          christopher.stone@libertyits.com
          austin.covrig@oddball.io
          kelly.lein@adhocteam.us
        ]
      )
    end
  end
end
