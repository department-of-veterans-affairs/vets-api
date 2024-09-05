# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::CleanUpPii, type: :job do
  let(:hlr_service) { instance_double(AppealsApi::RemovePii) }
  let(:nod_service) { instance_double(AppealsApi::RemovePii) }
  let(:sc_service) { instance_double(AppealsApi::RemovePii) }

  describe '#perform' do
    before do
      allow(AppealsApi::RemovePii)
        .to receive(:new).with(form_type: AppealsApi::HigherLevelReview).and_return(hlr_service)
      allow(AppealsApi::RemovePii)
        .to receive(:new).with(form_type: AppealsApi::NoticeOfDisagreement).and_return(nod_service)
      allow(AppealsApi::RemovePii)
        .to receive(:new).with(form_type: AppealsApi::SupplementalClaim).and_return(sc_service)
      allow(hlr_service).to receive(:run!)
      allow(nod_service).to receive(:run!)
      allow(sc_service).to receive(:run!)
    end

    it 'invokes AppealsApi::RemovePii for each appeal type' do
      described_class.new.perform
      expect(hlr_service).to have_received(:run!)
      expect(nod_service).to have_received(:run!)
      expect(sc_service).to have_received(:run!)
    end
  end
end
