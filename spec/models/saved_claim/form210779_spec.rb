# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedClaim::Form210779, type: :model do
  let(:valid_form_data) { build(:va210779).form }
  let(:invalid_form_data) { build(:va210779_invalid).form }
  let(:claim) { described_class.new(form:) }
  let(:form) { valid_form_data }

  describe 'validations' do
    context 'with valid form data' do
      it 'validates successfully' do
        expect(claim).to be_valid
      end
    end

    context 'with invalid form data' do
      let(:form) { invalid_form_data }

      it 'fails validation' do
        expect(claim).to be_invalid
      end
    end
  end

  describe '#send_confirmation_email' do
    it 'does not send email (MVP does not include email)' do
      expect(VANotify::EmailJob).not_to receive(:perform_async)
      claim.send_confirmation_email
    end
  end

  describe '#business_line' do
    it 'returns CMP for compensation claims' do
      expect(claim.business_line).to eq('CMP')
    end
  end

  describe '#document_type' do
    it 'returns 222 for nursing home' do
      expect(claim.document_type).to eq(222)
    end
  end

  describe '#regional_office' do
    it 'returns empty array' do
      expect(claim.regional_office).to eq([])
    end
  end

  describe '#process_attachments!' do
    it 'queues Lighthouse submission job without attachments' do
      expect(Lighthouse::SubmitBenefitsIntakeClaim).to receive(:perform_async).with(claim.id)
      claim.process_attachments!
    end
  end
end
