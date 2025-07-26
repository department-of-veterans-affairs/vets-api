# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/pdf_post_processor'

describe PdfFill::PdfPostProcessor do
  let(:processor) { described_class.new(old_file_path, combined_pdf_path, section_coordinates, form_class) }
  let(:old_file_path) { 'tmp/pdfs/file_path.pdf' }
  let(:combined_pdf_path) { 'tmp/pdfs/combined.pdf' }
  let(:section_coordinates) do
    [
      { page: 1, x: 10, y: 20, width: 100, height: 50, dest: 'Section_I' },
      { page: 2, x: 30, y: 40, width: 80, height: 30, dest: 'Section_II' }
    ]
  end
  let(:form_class) do
    PdfFill::Forms::Va210781v2
  end

  describe '#find_page_count' do
    subject do
      processor.find_page_count(old_file_path)
    end

    it 'returns the correct number of pages' do
      reader = instance_double(PDF::Reader, page_count: 3)
      allow(PDF::Reader).to receive(:new).with(old_file_path).and_return(reader)
      expect(subject).to eq(3)
    end
  end

  describe '#create_link' do
    subject do
      processor.create_link(doc, coord)
    end

    let(:doc) { double(HexaPDF::Document) }
    let(:coord) { { x: 10, y: 20, width: 100, height: 50, dest: 'SectionI' } }

    it 'creates a link annotation hash' do
      expect(doc).to receive(:add).with(hash_including(Type: :Annot, Subtype: :Link))
      subject
    end
  end

  describe '#add_links' do
    subject do
      processor.add_links(doc, section_coordinates, 0)
    end

    let(:page1) { {} }
    let(:page2) { {} }
    let(:doc) { double(HexaPDF::Document, pages: [page1, page2]) }

    it 'adds link annotations to the correct pages' do
      expect(doc).to receive(:add).with(hash_including(Type: :Annot, Subtype: :Link))
      expect(doc).to receive(:add).with(hash_including(Type: :Annot, Subtype: :Link))
      subject
    end
  end

  describe '#process!' do
    subject do
      processor.process!
    end

    it 'calls find_page_count and add_annotations' do
      allow(processor).to receive(:find_page_count).with(old_file_path).and_return(3)
      expect(processor).to receive(:add_annotations).with(combined_pdf_path, section_coordinates, 3)
      subject
    end
  end
end
