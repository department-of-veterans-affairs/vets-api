# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/pdf_post_processor'

describe PdfFill::PdfPostProcessor do
  subject do
    described_class.new(old_file_path, combined_pdf_path, section_coordinates, form_class)
  end

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
    it 'returns the correct number of pages' do
      reader = instance_double(PDF::Reader, page_count: 3)
      allow(PDF::Reader).to receive(:new).with(old_file_path).and_return(reader)
      expect(subject.find_page_count(old_file_path)).to eq(3)
    end
  end

  # describe '#add_destinations' do
  #   it 'adds destinations to the PDF document' do
  #     doc = instance_double(HexaPDF::Document)
  #     allow(doc).to receive(:pages).and_return(%i[page1 page2])
  #     # allow(doc).to receive(:add)
  #     allow(doc).to receive(:wrap)
  #     # allow(doc).to receive(:catalog)
  #     expect(doc).to receive(:add)
  #     expect(doc).to receive(:catalog)
  #     expect { subject.add_destinations(doc, form_class) }.not_to raise_error
  #   end
  # end

  describe '#prepare_link' do
    it 'returns the correct page object' do
      doc = double(HexaPDF::Document, pages: %i[page1 page2 page3])
      coord = { page: 2 }
      expect(subject.prepare_link(coord, doc, 1)).to eq(:page3)
    end
  end

  describe '#create_link' do
    it 'creates a link annotation hash' do
      doc = double(HexaPDF::Document)
      coord = { x: 10, y: 20, width: 100, height: 50, dest: 'SectionI' }
      expect(doc).to receive(:add).with(hash_including(Type: :Annot, Subtype: :Link))
      subject.create_link(doc, coord)
    end
  end

  # describe '#add_links' do
  #   it 'adds link annotations to the correct pages' do
  #     page1 = {}
  #     page2 = {}
  #     doc = double(HexaPDF::Document, pages: [page1, page2, {}])
  #     allow(doc).to receive(:add)
  #     # allow(subject).to receive(:prepare_link).and_return(page1, page2)
  #     # allow(subject).to receive(:create_link).and_return(:link1, :link2)
  #     # expect(page1).to receive(:[]=).with(:Annots, array_including(:link1)).at_least(:once)
  #     # expect(page2).to receive(:[]=).with(:Annots, []).at_least(:once)
  #     subject.add_links(doc, section_coordinates, 2)
  #     expect(doc).to receive(:add).with(hash_including(Type: :Annot, Subtype: :Link))
  #   end
  # end

  # describe '#process!' do
  #   subject(:find_page_count) { 3 }
  #   # expect(subject).to receive(:add_annotations).with(combined_pdf_path, section_coordinates, 3)

  #   # allow(subject).to receive(:find_page_count).with(old_file_path).and_return(3)
  #   it 'calls find_page_count and add_annotations' do
  #     # allow(subject).to receive(:find_page_count).with(old_file_path).and_return(3)
  #     expect(subject).to receive(:add_annotations).with(combined_pdf_path, section_coordinates, 3)
  #     subject.process!
  #   end
  # end
end
