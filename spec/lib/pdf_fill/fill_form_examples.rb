# frozen_string_literal: true

require 'rails_helper'

# Shared example for testing form fillers.
# This shared example assumes that the form filler class
# responds to a method `fill_form` that processes a form and
# outputs a filled PDF.
#
# The following options parameters are:
# - :form_id (String): Identifier for the form. (Required)
# - :factory (Symbol): Factory name for creating test data. (Required)
# - :use_vets_json_schema (Boolean): Whether to use Vets JSON schema for the form data. Default false.
# - :input_data_fixture_dir (String): Directory path for input data fixtures. Default to "pdf_fill/#{form_id}".
# - :output_pdf_fixture_dir (String): Directory path for output PDF fixtures. Default to "pdf_fill/#{form_id}".
# - :fill_options (Hash): Options to be passed to the `fill_form` method. Default empty.
# - :test_data_types (Array): Array of form data to validate. Defaults to %w[simple kitchen_sink overflow]
#
# Example Usage:
#
# it_behaves_like 'a form filler', {
#   form_id: described_class::FORM_ID,
#   factory: :pensions_saved_claim,
#   use_vets_json_schema: true,
#   input_data_fixture_dir: 'modules/pensions/spec/pdf_fill/fixtures',
#   output_pdf_fixture_dir: 'modules/pensions/spec/pdf_fill/fixtures'
#   test_data_types: %w[simple]
# }
RSpec.shared_examples 'a form filler' do |options|
  form_id, factory, test_data_types = options.values_at(:form_id, :factory, :test_data_types)
  test_data_types ||= %w[simple kitchen_sink overflow]

  describe PdfFill::Filler, type: :model do
    context "form #{form_id}", run_at: '2017-07-25 00:00:00 -0400' do
      let(:input_data_fixture_dir) { options[:input_data_fixture_dir] || "spec/fixtures/pdf_fill/#{form_id}" }
      let(:output_pdf_fixture_dir) { options[:output_pdf_fixture_dir] || "spec/fixtures/pdf_fill/#{form_id}" }

      test_data_types.each do |type|
        context "with #{type} test data" do
          let(:form_data) do
            return get_fixture_absolute("#{input_data_fixture_dir}/#{type}") unless options[:use_vets_json_schema]

            schema = "#{form_id.upcase}-#{type.upcase}"
            VetsJsonSchema::EXAMPLES.fetch(schema)
          end

          let(:saved_claim) do
            if %w[21P-530EZ 686C-674-V2].include?(form_id)
              claim = create(factory)
              claim.update(form: form_data.to_json)
              # refresh claim to reset instance methods like parsed_form
              SavedClaim.find(claim.id)
            else
              create(factory, form: form_data.to_json)
            end
          end

          before do
            allow(Flipper).to receive(:enabled?).with(anything).and_call_original
            allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(false)
          end

          it 'fills the form correctly' do
            if type == 'overflow'
              the_extras_generator = nil

              expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                the_extras_generator = extras_generator
                old_file_path
              end
            end

            file_path = if options[:fill_options]
                          described_class.fill_form(saved_claim, nil, options[:fill_options])
                        else
                          # Should be able to call without any additional arguments
                          described_class.fill_form(saved_claim)
                        end

            if type == 'overflow'
              extras_path = the_extras_generator.generate

              expected_extras = if options[:fill_options] && options[:fill_options][:extras_redesign]
                                  'overflow_redesign_extras.pdf'
                                else
                                  'overflow_extras.pdf'
                                end

              expect(extras_path).to match_file_exactly("#{output_pdf_fixture_dir}/#{expected_extras}")

              File.delete(extras_path)
            end

            expect(file_path).to match_pdf_fields("#{output_pdf_fixture_dir}/#{type}.pdf")

            File.delete(file_path)
          end
        end
      end
    end
  end
end
