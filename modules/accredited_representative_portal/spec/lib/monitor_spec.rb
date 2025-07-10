# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::Monitor do
  let(:monitor) { described_class.new }

  describe '#service_name' do
    it 'returns the expected name' do
      expect(monitor.send(:service_name)).to eq('accredited-representative-portal')
    end
  end

  describe '#form_id' do
    it 'returns PROPER_FORM_ID' do
      expect(monitor.send(:form_id)).to eq(SavedClaim::BenefitsIntake::DependencyClaim::PROPER_FORM_ID)
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
