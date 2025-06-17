# frozen_string_literal: true

require 'rails_helper'
require 'common/convert_to_pdf'
require 'ostruct'

describe IvcChampva::PdfCombiner do
  before do
    @form_path = 'modules/ivc_champva/spec/fixtures/pdfs/vha_10_10d-filled.pdf'
    @merged_path = 'modules/ivc_champva/spec/fixtures/pdfs/vha_10_10d-merged.pdf'
    @image_path = 'modules/ivc_champva/spec/fixtures/images/test_image.pdf'
    @doctors_note_path = 'spec/fixtures/files/doctors-note.pdf'
  end

  after do
    # for manual inspection, uncomment this line to see the merged PDF
    FileUtils.rm_f(@merged_path)
  end

  describe '#combine' do
    it 'does not combine if there are no additional files' do
      expect(IvcChampva::PdfCombiner.combine(@merged_path, [])).to eq(@merged_path)
      expect(File).not_to exist(@merged_path)
    end

    it 'combines PDF files' do
      pages = [@form_path, @image_path]
      expect(IvcChampva::PdfCombiner.combine(@merged_path, pages)).to eq(@merged_path)

      # Check that the merged file has the correct number of pages
      merged_pdf = CombinePDF.load(@merged_path)
      expect(merged_pdf.pages.count).to eq(pages.count)
    end

    it 'combines PDF files and maintains page order' do
      pages = [@form_path, @image_path, @doctors_note_path]
      expect(IvcChampva::PdfCombiner.combine(@merged_path, pages)).to eq(@merged_path)

      merged_pdf = CombinePDF.load(@merged_path)
      expect(merged_pdf.pages.count).to eq(pages.count)

      # ensure order matches pages array
      merged_pdf.pages.each_with_index do |page, index|
        expect(page[:SourceFileName]).to eq(pages[index])
      end
    end
  end
end
