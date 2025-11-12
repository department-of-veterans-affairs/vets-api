# frozen_string_literal: true

require 'rails_helper'
require 'lib/pdf_fill/fill_form_examples'

describe PdfFill::Forms::Va212680 do
  let(:form_data) { build(:form212680Simple, country:).parsed_form }
  let(:form) { described_class.new(form_data) }

  it_behaves_like 'a form filler', {
    form_id: '21-2680',
    factory: :form212680Simple,
    use_vets_json_schema: true,
    output_pdf_fixture_dir: 'spec/fixtures/pdf_fill/21-2680',
    test_data_types: %w[simple],
    run_at: '2025-10-24T18:48:27Z'
  }

  describe '#extract_country_expanded' do
    context 'with countries of length 2' do
      let(:country) { 'US' }

      it 'returns US' do
        merged = form.merge_fields
        expect(merged['claimantInformation']['address']['country']).to eq('US')
      end
    end

    context 'with countries of length 3' do
      let(:country) { 'USA' }

      it 'returns US' do
        merged = form.merge_fields
        expect(merged['claimantInformation']['address']['country']).to eq('US')
      end
    end
  end
end
