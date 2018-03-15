# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersistentAttachments::PensionBurial do
  let(:file) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
  let(:instance) { described_class.new(form_id: 'T-123') }

  it 'sets a guid on initialize' do
    expect(instance.guid).to be_a(String)
  end

  it 'allows adding a file' do
    allow(ClamScan::Client).to receive(:scan)
      .and_return(instance_double('ClamScan::Response', safe?: true))
    instance.file = file.open
    expect(instance.valid?).to be(true)
    expect(instance.file.shrine_class).to be(ClaimDocumentation::Uploader)
  end

  describe '#can_upload_to_api?' do
    it 'returns true if email is right' do
      instance.saved_claim = SavedClaim::Burial.new(form: { claimantEmail: 'lihan@adhocteam.us' }.to_json)
      expect(instance.can_upload_to_api?).to eq(true)
    end
  end

  context 'stamp_text', run_at: '2017-08-01 01:01:00 EDT' do
    it 'offsets a user timestamp by their browser data' do
      instance.saved_claim = FactoryBot.create(
        :burial_claim
      )
      expect(instance.send(:stamp_text)).to eq('2017-08-01')
    end
  end
end
