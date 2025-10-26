# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimHelper do
  # Dummy class so we can test the concern methods
  let(:dummy_class) do
    Class.new do
      include ClaimHelper
      attr_accessor :claims_service
    end
  end

  let(:instance) { dummy_class.new }
  let(:appointment_id) { 'aa0f63e0-5fa7-4d74-a17a-a6f510dbf69e' }
  let(:claim_id) { '3fa85f64-5717-4562-b3fc-2c963f66afa6' }

  describe '#create_claim' do
    it 'logs and returns claimId from claims_service' do
      claims_service_double = instance_double(TravelPay::ClaimsService)
      allow(claims_service_double).to receive(:create_new_claim)
        .with({ 'btsss_appt_id' => appointment_id })
        .and_return({ 'claimId' => claim_id })

      instance.claims_service = claims_service_double

      expect(instance.create_claim(appointment_id, 'complex')).to eq(claim_id)
    end
  end
end
