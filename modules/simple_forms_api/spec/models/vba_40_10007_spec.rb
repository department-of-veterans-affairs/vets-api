# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::VBA4010007' do
  describe 'handle_attachments' do
    it 'saves the merged pdf' do
      original_pdf = double('HexaPDF::Document')
      combined_pdf = double('HexaPDF::Document')
      original_file_path = 'original-file-path'
      attachment_page_path = 'attachment_page.pdf'
      page = double('HexaPDF::Page')

      form = FactoryBot.build(:vba4010007)

      allow(HexaPDF::Document).to receive(:open).with(original_file_path).and_return(original_pdf)
      allow(HexaPDF::Document).to receive(:open).with(attachment_page_path).and_return(combined_pdf)

      allow(combined_pdf).to receive(:pages).and_return([page])
      allow(original_pdf).to receive(:pages).and_return([page])

      allow(original_pdf).to receive(:import).with(page).and_return(page)

      allow(original_pdf).to receive(:write).with(original_file_path, optimize: true)

      allow(form).to receive(:create_attachment_page).with(attachment_page_path)

      form.handle_attachments(original_file_path)

      expect(HexaPDF::Document).to have_received(:open).with(original_file_path)
      expect(HexaPDF::Document).to have_received(:open).with(attachment_page_path)
      expect(original_pdf).to have_received(:write).with(original_file_path, optimize: true)
    end
  end
end
