# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::UnsuccessfulReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      described_class.build(1.day.ago, Time.zone.now, consumer_claims_totals: [],
                                                      unsuccessful_claims_submissions: [],
                                                      poa_totals: [],
                                                      unsuccessful_poa_submissions: [],
                                                      ews_totals: [],
                                                      unsuccessful_evidence_waiver_submissions: [],
                                                      itf_totals: []).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Daily Submission Report')
    end

    it 'sends to the right people' do
      expect(subject.to).to eq(
        %w[
          alex.wilson@oddball.io
          austin.covrig@oddball.io
          david.mazik@va.gov
          emily.goodrich@oddball.io
          janet.coutinho@va.gov
          jennica.stiehl@oddball.io
          kayla.watanabe@adhocteam.us
          matt.king@adhocteam.us
          matthew.christianson@adhocteam.us
          premal.shah@va.gov
          robert.perea-martinez@adhocteam.us
          stone_christopher@bah.com
          zachary.goldfine@va.gov
        ]
      )
    end
  end
end
