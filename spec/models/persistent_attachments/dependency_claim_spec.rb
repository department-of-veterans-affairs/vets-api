# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PersistentAttachments::DependencyClaim, uploader_helpers: true do
  let(:file) { Rails.root.join('spec', 'fixtures', 'files', 'marriage-certificate.pdf') }
  let(:instance) { described_class.new(form_id: '686C-674') }

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

  context 'stamp_text', run_at: '2017-08-01 01:01:00 EDT' do
    it 'offsets a user timestamp by their browser data' do
      instance.saved_claim = FactoryBot.create(
        :dependency_claim
      )
      expect(instance.send(:stamp_text)).to eq('2017-08-01')
    end
  end

  describe '#delete_file' do
    stub_virus_scan

    it 'deletes the file after destroying the model' do
      instance.file = file.open
      instance.save!
      shrine_file = instance.file
      expect(shrine_file.exists?).to eq(true)
      instance.destroy
      expect(shrine_file.exists?).to eq(false)
    end
  end
end
