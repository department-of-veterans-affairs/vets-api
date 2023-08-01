# frozen_string_literal: true

require 'digest'
require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::PdfDownloads do
  include FixtureHelpers

  describe '#watermark' do
    let(:input_pdf_path) { fixture_filepath('higher_level_reviews/v0/pdfs/v3/expected_200996.pdf') }
    let!(:output_pdf_path) { described_class.watermark(input_pdf_path, 'output.pdf') }

    after do
      # FIXME: Test this in a more robust way
      # The watermark's text is diagonal, and the `match_pdf` matcher we have is not able to correctly detect it
      # (it instead appears jumbled with the rest of the form's text). For now, watermark code needs to be validated
      # manually by commenting this out and looking at the generated file in the rails tmp folder:
      FileUtils.rm_f(output_pdf_path)
    end

    it 'generates a version of the PDF with text unchanged and the watermark on each page' do
      expect(output_pdf_path).not_to match_pdf(input_pdf_path)
    end
  end
end
