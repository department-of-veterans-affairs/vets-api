# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

describe PdfFill::Filler, type: :model do
  include SchemaMatchers
  test_data_types ||= %w[simple kitchen_sink overflow]

  xcontext 'Form filler', run_at: '2017-07-25 00:00:00 -0400' do # rubocop:disable RSpec/PendingWithoutReason
    skip 'Pending implementation of PDF form filling functionality for 21P-0969 form'

    let(:factory) { :income_and_assets_claim }
    let(:input_data_fixture_dir) { 'modules/income_and_assets/spec/fixtures/pdf_fill/21P-0969' }
    let(:output_pdf_fixture_dir) { 'modules/income_and_assets/spec/fixtures/pdf_fill/21P-0969' }

    test_data_types.each do |type|
      context "with #{type} test data" do
        let(:form_data) do
          schema = "21P-0969-#{type.upcase}"
          VetsJsonSchema::EXAMPLES.fetch(schema)
        end

        let(:saved_claim) { create(factory, form: form_data.to_json) }

        it 'fills the form correctly' do
          if type == 'overflow'
            the_extras_generator = nil

            expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
              the_extras_generator = extras_generator
              old_file_path
            end
          end

          file_path = described_class.fill_form(saved_claim)

          if type == 'overflow'
            extras_path = the_extras_generator.generate

            expect(
              FileUtils.compare_file(extras_path, "#{output_pdf_fixture_dir}/overflow_extras.pdf")
            ).to be(true)

            File.delete(extras_path)
          end

          expect(
            pdfs_fields_match?(file_path, "#{output_pdf_fixture_dir}/#{type}.pdf")
          ).to be(true)

          File.delete(file_path)
        end
      end
    end
  end
end
