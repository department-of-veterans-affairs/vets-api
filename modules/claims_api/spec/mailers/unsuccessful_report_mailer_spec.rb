# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::UnsuccessfulReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(1.day.ago, Time.zone.now, consumer_claims_totals: [],
                                                      unsuccessful_claims_submissions: [],
                                                      poa_totals: [],
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
