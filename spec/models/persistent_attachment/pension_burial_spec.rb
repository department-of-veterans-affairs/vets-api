# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PersistentAttachment::PensionBurial do
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

  context '#process' do
    it 'starts a background process' do
      instance.saved_claim = FactoryGirl.create(:burial_claim)
      klass = ClaimDocumentation::PensionBurial::File
      expect(klass).to receive(:new).with(hash_including(guid: instance.guid)).and_return(double(klass, start!: true))
      instance.process
    end
  end
end
