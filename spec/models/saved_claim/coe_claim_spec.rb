# frozen_string_literal: true

require 'rails_helper'
require 'lgy/service'

RSpec.describe SavedClaim::CoeClaim do
  describe '#send_to_lgy(edipi:, icn:)' do
    it 'logs an error to sentry if edipi is nil' do
      coe_claim = create(:coe_claim)
      allow(coe_claim).to receive(:prepare_form_data).and_return({})
      allow_any_instance_of(LGY::Service).to receive(:put_application).and_return({})
      expect(coe_claim).to receive(:log_message_to_sentry).twice
      coe_claim.send_to_lgy(edipi: nil, icn: nil)
    end

    it 'logs an error to sentry if edipi is an empty string' do
      coe_claim = create(:coe_claim)
      allow(coe_claim).to receive(:prepare_form_data).and_return({})
      allow_any_instance_of(LGY::Service).to receive(:put_application).and_return({})
      expect(coe_claim).to receive(:log_message_to_sentry).twice
      coe_claim.send_to_lgy(edipi: '', icn: nil)
    end
  end
end
