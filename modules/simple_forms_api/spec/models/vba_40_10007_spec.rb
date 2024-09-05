# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SimpleFormsApi::VBA4010007' do
  describe 'handle_attachments' do
    it 'saves the combined pdf' do
      original_pdf = double
      combined_pdf = double
      original_file_path = 'original-file-path'
      new_file_path = 'new-file-path'
      form = SimpleFormsApi::VBA400247.new(
        {
          'additional_address' => {
            'street' => '123 Fake St.',
            'city' => 'Fakesville',
            'state' => 'Fakesylvania',
            'postal_code' => '12345',
            'country' => 'US'
          }
        }
      )
      allow_any_instance_of(SimpleFormsApi::PdfFiller).to receive(:generate).and_return(new_file_path)
      allow(CombinePDF).to receive(:new).and_return(combined_pdf)
      allow(combined_pdf).to receive(:<<)
      allow(combined_pdf).to receive(:save).with(original_file_path)
      allow(CombinePDF).to receive(:load).with(original_file_path).and_return(original_pdf)
      allow(CombinePDF).to receive(:load).with(new_file_path)

      form.handle_attachments(original_file_path)

      expect(combined_pdf).to have_received(:save).with(original_file_path)
    end
  end
end
