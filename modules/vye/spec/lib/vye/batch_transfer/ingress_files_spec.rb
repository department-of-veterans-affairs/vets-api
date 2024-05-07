# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::IngressFiles do
  describe '#bdn_feed_filename' do
    it 'returns a string' do
      expect(described_class.bdn_feed_filename).to be_a(String)
    end
  end

  describe '#tims_feed_filename' do
    it 'returns a string' do
      expect(described_class.tims_feed_filename).to be_a(String)
    end
  end

  it 'imports lines from TIMS extract' do
    file = Vye::Engine.root / 'spec/fixtures/tims_sample/tims32towave.txt'
    data = CSV.open(file, 'r', headers: %i[ssn file_number doc_type queue_date rpo])

    expect do
      described_class.tims_import(data)
    end.to(
      change(Vye::UserProfile, :count).by(20).and(
        change(Vye::PendingDocument, :count).by(20)
      )
    )
  end
end
