# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

module AppealsApi
  RSpec.describe LineOfBusiness do
    describe '#value' do
      it 'returns the appropriate LOB for an evidence submission' do
        supplemental_claim = FactoryBot.create(:supplemental_claim)
        upload_submission = FactoryBot.create(:upload_submission, consumer_name: 'appeals_api_sc_evidence_submission')
        FactoryBot.create(:sc_evidence_submission, upload_submission: upload_submission,
                                                   supportable: supplemental_claim)

        lob = LineOfBusiness.new(upload_submission)

        # compensation is the default value of valid_200995.json
        expect(lob.value).to eq('CMP')
      end
    end
  end
end
