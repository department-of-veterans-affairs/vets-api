# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::BdnChunk do
  describe '::new' do
    let!(:bdn_clone) { FactoryBot.create(:vye_bdn_clone_base, is_active: nil) }
    let(:bdn_clone_id) { bdn_clone.id }
    let(:offset) { 0 }
    let(:block_size) { 1000 }
    let(:filename) { 'test.txt' }

    it 'can be instantiated' do
      expect(described_class.new(bdn_clone_id:, offset:, block_size:, filename:)).to be_a described_class
    end
  end

  describe '::feed_filename' do
    it 'returns a string' do
      expect(described_class.send(:feed_filename)).to be_a(String)
    end
  end

  describe '#import' do
    let!(:bdn_clone) { FactoryBot.create(:vye_bdn_clone_base, is_active: nil) }
    let(:bdn_clone_id) { bdn_clone.id }

    let(:offset) { 0 }
    let(:block_size) { 1000 }
    let(:filename) { 'test_0.txt' }
    let(:chunk) { described_class.new(bdn_clone_id:, offset:, block_size:, filename:) }

    let(:file) { Vye::Engine.root / 'spec/fixtures/bdn_sample/WAVE.txt' }

    it 'imports the data from the bdn feed' do
      expect(chunk).to receive(:file).and_return(file)

      expect do
        chunk.import
      end.to(
        change(Vye::UserProfile, :count).by(1).and(
          change(Vye::UserInfo, :count).by(1).and(
            change(Vye::Award, :count).by(1)
          )
        )
      )

      expect(Vye::Award.first.monthly_rate).to eq(35)
    end
  end
end
