# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::SubmissionReportMailer, type: [:mailer] do
  describe '#build' do
    subject do
      from = 1.month.ago
      to = Time.zone.now

      claim = create(:auto_established_claim, :established)
      ClaimsApi::ClaimSubmission.create claim:, claim_type: 'PACT', consumer_label: 'Consumer name here'

      described_class.build(
        from,
        to,
        consumer_claims_totals: [],
        poa_totals: [],
        ews_totals: [],
        itf_totals: []
      ).deliver_now
    end

    it 'sends the email' do
      expect(subject.subject).to eq('Benefits Claims Monthly Submission Report')
    end

    it 'sends to the right people' do
      expect(subject.to).to match_array(
        %w[
          david.mazik@va.gov
          drew.fisher@adhocteam.us
          eshvimmer@deloitte.com
          janet.coutinho@va.gov
          jgreene@technatomy.com
          mbavanaka@deloitte.com
          mchristianson@technatomy.com
          michael.clement@adhocteam.us
          michael.harlow@va.gov
          mughumman@deloitte.com
          mzanaty@technatomy.com
          robert.perea-martinez@adhocteam.us
          rrice@technatomy.com
          slamsal@deloitte.com
          stone_christopher@bah.com
          zachary.goldfine@va.gov
        ]
      )
    end
  end
end
