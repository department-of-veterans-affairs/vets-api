# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::LineOfBusiness do
  describe '#value' do
    it 'returns the appropriate LOB for an evidence submission' do
      supplemental_claim = create(:supplemental_claim)
      upload_submission = create(:upload_submission, consumer_name: 'appeals_api_sc_evidence_submission')
      create(:sc_evidence_submission, upload_submission:, supportable: supplemental_claim)

      lob = AppealsApi::LineOfBusiness.new(upload_submission)

      # fiduciary is the default value of valid_200995.json
      expect(lob.value).to eq('FID')
    end
  end
end
