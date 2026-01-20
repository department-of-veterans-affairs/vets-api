# frozen_string_literal: true

require 'rails_helper'
require 'accredited_representative_portal/monitor'

RSpec.describe AccreditedRepresentativePortal::Monitor do
  let(:claim) { create(:saved_claim_benefits_intake) }
  let(:monitor) { described_class.new(claim:) }

  before do
    # This removes: SHRINE WARNING: Error occurred when attempting to extract image dimensions:
    # #<FastImage::UnknownImageType: FastImage::UnknownImageType>
    allow(FastImage).to receive(:size).and_wrap_original do |original, file|
      if file.respond_to?(:path) && file.path.end_with?('.pdf')
        nil
      else
        original.call(file)
      end
    end
  end

  describe '#service_name' do
    it 'returns the expected name' do
      expect(monitor.send(:service_name)).to eq('accredited-representative-portal')
    end
  end

  describe '#form_id' do
    it 'returns PROPER_FORM_ID from the claim class' do
      expect(monitor.send(:form_id)).to eq(AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::DependencyClaim::PROPER_FORM_ID)
    end
  end

  describe '#send_email' do
    it 'delegates to NotificationEmail' do
      email = double
      expect(AccreditedRepresentativePortal::NotificationEmail).to receive(:new).with(123).and_return(email)
      expect(email).to receive(:deliver).with(:error)
      monitor.send(:send_email, 123, :error)
    end
  end
end
