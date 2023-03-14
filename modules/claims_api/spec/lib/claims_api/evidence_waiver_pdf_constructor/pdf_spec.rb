# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/evidence_waiver_pdf/pdf'
require_relative '../../../support/pdf_matcher'

# Helpful testing hints
#
# `cp #{generated_pdf} #{expected_pdf}`; sleep 1
# `open #{generated_pdf} #{expected_pdf}`; sleep 1
#
describe ClaimsApi::EvidenceWaiver do
  before do
    Timecop.freeze(Time.zone.parse('2022-01-01T08:00:00Z'))
  end

  after do
    Timecop.return
  end

  let(:ews) { create(:claims_api_evidence_waiver_submission, :with_full_headers_tamara) }

  context 'normal name' do
    it 'construct pdf' do
      constructor = ClaimsApi::EvidenceWaiver.new(auth_headers: ews.auth_headers)
      expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', '5103',
                                     'signed_filled_final.pdf')
      generated_pdf = constructor.construct(response: true)
      expect(generated_pdf).to match_pdf_content_of(expected_pdf)
    end
  end

  context 'long name' do
    xit 'construct truncated pdf' do
      ews.auth_headers['va_eauth_lastName'] = 'Ellis-really-long-truncated-name-here'
      constructor = ClaimsApi::EvidenceWaiver.new(auth_headers: ews.auth_headers)
      expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', '5103',
                                     'signed_filled_final_long.pdf')
      generated_pdf = constructor.construct({ response: true })
      expect(generated_pdf).to match_pdf_content_of(expected_pdf)
    end
  end
end
