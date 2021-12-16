# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::SupplementalClaimCleanUpPii, type: :job do
  let(:service) { instance_double(AppealsApi::RemovePii) }

  describe '#perform' do
    before do
      allow(AppealsApi::RemovePii).to receive(:new).and_return(service)
      allow(service).to receive(:run!)
    end

    context 'when pii_expunge flag is enabled' do
      it 'calls AppealsApi::RemovePii' do
        with_settings(Settings.modules_appeals_api, supplemental_claim_pii_expunge_enabled: true) do
          described_class.new.perform
          expect(service).to have_received(:run!)
        end
      end
    end

    context 'when pii_expunge flag is disabled' do
      it 'does not call AppealsApi::RemovePii' do
        with_settings(Settings.modules_appeals_api, supplemental_claim_pii_expunge_enabled: false) do
          described_class.new.perform
          expect(service).not_to have_received(:run!)
        end
      end
    end
  end
end
