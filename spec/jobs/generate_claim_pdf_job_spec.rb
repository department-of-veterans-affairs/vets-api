# frozen_string_literal: true
require 'rails_helper'

RSpec.describe GenerateClaimPDFJob do
  describe '#perform' do
    let(:claim) { FactoryBot.create(:burial_claim) }
    let(:spec_file) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
    let(:tmpfile) { Tempfile.new }
    before do
      FileUtils.cp spec_file, tmpfile
    end
    it 'creates an attachment for the claim' do
      allow(ClamScan::Client).to receive(:scan)
        .and_return(instance_double('ClamScan::Response', safe?: true))
      allow(SavedClaim).to receive(:find).with(claim.id).and_return(claim)
      expect(claim).to receive(:to_pdf).and_return(tmpfile.open)
      expect { subject.perform(claim.id) }.to change {
        claim.reload && claim.persistent_attachments.count
      }.from(0).to(1)
    end
  end
end
