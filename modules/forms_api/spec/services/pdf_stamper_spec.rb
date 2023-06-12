# frozen_string_literal: true

require 'rails_helper'
require FormsApi::Engine.root.join('spec', 'spec_helper.rb')

describe FormsApi::PdfStamper do
  def self.test_pdf_stamp_error(stamp_method, test_payload)
    it 'raises an error when generating stamped file' do
      allow(Common::FileHelpers).to receive(:random_file_path).and_return('fake/stamp_path')
      allow(Common::FileHelpers).to receive(:delete_file_if_exists)
      allow(Prawn::Document).to receive(:generate).and_raise('Error generating stamped file')

      generated_form_path = 'fake/generated_form_path'
      data = JSON.parse(File.read("modules/forms_api/spec/fixtures/form_json/#{test_payload}.json"))

      expect do
        FormsApi::PdfStamper.send(stamp_method, generated_form_path, data)
      end.to raise_error(RuntimeError, 'Error generating stamped file')

      expect(Common::FileHelpers).to have_received(:delete_file_if_exists).with('fake/stamp_path')
    end
  end

  test_pdf_stamp_error 'stamp214142', 'vba_21_4142'
  test_pdf_stamp_error 'stamp2110210', 'vba_21_10210'
  test_pdf_stamp_error 'stamp21p0847', 'vba_21p_0847'
end
