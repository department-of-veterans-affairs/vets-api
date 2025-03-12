# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/shared_examples_for_base_form'

RSpec.describe SimpleFormsApi::VBA400247 do
  it_behaves_like 'zip_code_is_us_based', %w[applicant_address]

  describe 'handle_attachments' do
    it 'saves the combined pdf' do
      original_pdf = double('HexaPDF::Document')
      attachment_pdf = double('HexaPDF::Document')
      pages_mock = double('HexaPDF::PageList')
      page_mock = double('HexaPDF::Page')
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
      allow(HexaPDF::Document).to receive(:open).with(original_file_path).and_return(original_pdf)
      allow(HexaPDF::Document).to receive(:open).with(new_file_path).and_return(attachment_pdf)

      allow(original_pdf).to receive(:import).with(page_mock).and_return(page_mock)
      allow(original_pdf).to receive(:pages).and_return(pages_mock)
      allow(attachment_pdf).to receive(:pages).and_return(pages_mock)

      allow(pages_mock).to receive(:each).and_yield(page_mock)
      allow(pages_mock).to receive(:<<)

      allow(original_pdf).to receive(:write).with(original_file_path, optimize: true)

      form.handle_attachments(original_file_path)

      expect(original_pdf).to have_received(:write).with(original_file_path, optimize: true)
      expect(pages_mock).to have_received(:<<).at_least(:once).with(page_mock)
    end
  end

  describe '#notification_first_name' do
    let(:data) do
      {
        'applicant_full_name' => {
          'first' => 'Applicant',
          'last' => 'Eteranvay'

        }
      }
    end

    it 'returns the first name to be used in notifications' do
      expect(described_class.new(data).notification_first_name).to eq 'Applicant'
    end
  end

  describe '#notification_email_address' do
    let(:data) do
      { 'applicant_email' => 'a@b.com' }
    end

    it 'returns the email address to be used in notifications' do
      expect(described_class.new(data).notification_email_address).to eq 'a@b.com'
    end
  end
end
