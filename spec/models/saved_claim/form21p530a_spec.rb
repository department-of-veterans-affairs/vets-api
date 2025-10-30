# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Form21p530a, type: :model do
  let(:minimal_form_data) { {} }
  let(:claim) { described_class.new(form: minimal_form_data.to_json) }

  describe 'FORM constant' do
    it 'is set to 21P-530a' do
      expect(described_class::FORM).to eq('21P-530a')
    end
  end

  describe 'validations' do
    it 'requires form to be present' do
      expect(described_class.new(form: nil)).not_to be_valid
    end

    it 'accepts a JSON string for form' do
      expect(claim).to be_valid
    end
  end

  describe '#process_attachments!' do
    it 'queues Lighthouse submission job' do
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(claim.id)
      claim.process_attachments!
    end
  end

  describe '#send_confirmation_email' do
    it 'does not send email (not included in MVP)' do
      expect { claim.send_confirmation_email }.not_to raise_error
    end
  end

  describe '#regional_office' do
    it 'returns empty array' do
      expect(claim.regional_office).to eq([])
    end
  end

  describe '#business_line' do
    it "returns 'NCA' for burial-related claims" do
      expect(claim.business_line).to eq('NCA')
    end
  end

  describe '#document_type' do
    it 'returns 133 for burial applications' do
      expect(claim.document_type).to eq(133)
    end
  end

  describe '#attachment_keys' do
    it 'returns empty array (no attachments in MVP)' do
      expect(claim.attachment_keys).to eq([])
    end
  end
end
