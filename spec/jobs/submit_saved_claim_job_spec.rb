# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubmitSavedClaimJob, uploader_helpers: true do
  describe '#perform' do
    stub_virus_scan

    let(:claim) { FactoryBot.create(:burial_claim) }
    before do
      create(:pension_burial, saved_claim: claim)
    end

    it 'submits the saved claim' do
      binding.pry; fail
      SubmitSavedClaimJob.new.perform(claim.id)
    end
  end
end
