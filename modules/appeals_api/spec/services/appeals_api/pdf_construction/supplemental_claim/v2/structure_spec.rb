# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::SupplementalClaim::V2::Structure do
  let(:supplemental_claim) { create(:extra_supplemental_claim) }

  describe '#form_fill' do
    it 'returns a Hash' do
      result = described_class.new(supplemental_claim).form_fill

      expect(result.class).to eq(Hash)
    end
  end

  describe '#insert_overlaid_pages' do
    it 'returns a temporary overlaid pdf path' do
      form_fill_path = Prawn::Document.new.render_file("/tmp/#{supplemental_claim.id}.pdf")
      result = described_class.new(supplemental_claim).insert_overlaid_pages(form_fill_path)

      expect(result).to eq("/tmp/#{supplemental_claim.id}-overlaid-form-fill-tmp.pdf")
    end
  end

  describe 'add_additional_pages' do
    it 'returns a Prawn::Document' do
      result = described_class.new(supplemental_claim).add_additional_pages
      expect(result.class).to eq(Prawn::Document)
    end

    it 'has 1 page' do
      result = described_class.new(supplemental_claim).add_additional_pages
      expect(result.page_count).to eq(1)
    end
  end

  describe 'form_title' do
    it 'returns the supplemental claim doc title' do
      expect(described_class.new(supplemental_claim).form_title).to eq('200995')
    end
  end
end
