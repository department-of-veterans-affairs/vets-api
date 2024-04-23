# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::NoticeOfDisagreementCleanUpPii, type: :job do
  let(:service) { instance_double(AppealsApi::RemovePii) }

  describe '#perform' do
    before do
      allow(AppealsApi::RemovePii).to receive(:new).and_return(service)
      allow(service).to receive(:run!)
    end

    context 'when pii_expunge flag is enabled' do
      before { Flipper.enable :decision_review_nod_pii_expunge_enabled }

      it 'calls AppealsApi::RemovePii' do
        described_class.new.perform
        expect(service).to have_received(:run!)
      end
    end

    context 'when pii_expunge flag is disabled' do
      before { Flipper.disable :decision_review_nod_pii_expunge_enabled }

      it 'does not call AppealsApi::RemovePii' do
        described_class.new.perform
        expect(service).not_to have_received(:run!)
      end
    end
  end
end
