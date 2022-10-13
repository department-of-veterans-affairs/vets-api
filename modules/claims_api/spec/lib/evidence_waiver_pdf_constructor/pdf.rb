# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/evidence_waiver_pdf/pdf'
require_relative '../../support/pdf_matcher'

describe ClaimsApi::EvidenceWaiver do
  before do
    Timecop.freeze(Time.zone.parse('2022-01-01T08:00:00Z'))
  end

  after do
    Timecop.return
  end

  context 'normal name' do
    it 'construct pdf' do
      target_veteran = OpenStruct.new({
                                        'first_name' => 'Tamera',
                                        'last_name' => 'Ellis'
                                      })
      constructor = ClaimsApi::EvidenceWaiver.new(target_veteran: target_veteran)
      expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', '5103',
                                     'signed_filled_final.pdf')
      generated_pdf = constructor.construct({ response: true })
      expect(generated_pdf).to match_pdf_content_of(expected_pdf)
    end
  end

  context 'long name' do
    it 'construct truncated pdf' do
      target_veteran = OpenStruct.new({
                                        'first_name' => 'Tamera',
                                        'last_name' => 'Ellis-really-long-truncated-name-here'
                                      })
      constructor = ClaimsApi::EvidenceWaiver.new(target_veteran: target_veteran)
      expected_pdf = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', '5103',
                                     'signed_filled_final_long.pdf')
      generated_pdf = constructor.construct({ response: true })
      expect(generated_pdf).to match_pdf_content_of(expected_pdf)
    end
  end
end
