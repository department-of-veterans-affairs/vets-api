# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lighthouse::BenefitsIntake::DeleteOldClaims, :uploader_helpers, type: :model do
  describe '#perform' do
    stub_virus_scan

    it 'deletes old central mail claims' do
      new_attachment_success = create(:pension_burial)
      old_attachment_pending = create(:pension_burial)
      old_attachment_success = create(:pension_burial)
      file = old_attachment_success.file
      [new_attachment_success, old_attachment_success].each do |attachment|
        attachment.saved_claim.central_mail_submission.update(state: 'success')
      end

      [old_attachment_pending, old_attachment_success].each do |attachment|
        attachment.saved_claim.update(created_at: 2.months.ago - 1.day)
      end

      described_class.new.perform

      expect(model_exists?(new_attachment_success)).to eq(true)
      expect(model_exists?(old_attachment_pending)).to eq(true)

      expect(model_exists?(old_attachment_success)).to eq(false)
      expect(model_exists?(old_attachment_success.saved_claim)).to eq(false)
      expect(model_exists?(old_attachment_success.saved_claim.central_mail_submission)).to eq(false)
      expect(file.exists?).to eq(false)
    end
  end
end
