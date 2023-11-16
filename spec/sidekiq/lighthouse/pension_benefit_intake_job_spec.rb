# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::PensionBenefitIntakeJob, uploader_helpers: true do
  stub_virus_scan
  let(:pension_burial) { create(:pension_burial) }
  let(:claim) { pension_burial.saved_claim }

  describe '#perform' do
    let(:job) { described_class.new }
  end
end
