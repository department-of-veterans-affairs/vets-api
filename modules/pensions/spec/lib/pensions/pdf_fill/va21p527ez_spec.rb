# frozen_string_literal: true

require 'rails_helper'
require 'pensions/pdf_fill/va21p527ez'
require 'lib/pdf_fill/fill_form_examples'

def basic_class
  Pensions::PdfFill::Va21p527ez.new({})
end

describe Pensions::PdfFill::Va21p527ez do
  include SchemaMatchers

  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-527EZ-KITCHEN_SINK')
  end

  it_behaves_like 'a form filler', {
    form_id: described_class::FORM_ID,
    factory: :pensions_saved_claim,
    use_vets_json_schema: true,
    input_data_fixture_dir: 'modules/pensions/spec/fixtures',
    output_pdf_fixture_dir: 'modules/pensions/spec/fixtures',
    use_ocr: true,
    ocr_end_page: 7,
    fill_options: { extras_redesign: true, omit_esign_stamp: true }
  }

  describe '#merge_fields' do
    it 'merges the right fields' do
      Timecop.freeze(Time.zone.parse('2016-12-31 00:00:00 EDT')) do
        expected = get_fixture_absolute("#{Pensions::MODULE_PATH}/spec/fixtures/merge_fields")
        actual = described_class.new(form_data).merge_fields

        # Create a diff that is easy to read when expected/actual differ
        diff = Hashdiff.diff(expected, actual)

        expect(diff).to eq([])
      end
    ensure
      Timecop.return
    end
  end
end
