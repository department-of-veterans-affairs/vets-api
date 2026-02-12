# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/pdf_fill/filler'

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
  form_id, factory, test_data_types, run_at = options.values_at(:form_id, :factory, :test_data_types, :run_at)
  test_data_types ||= %w[simple kitchen_sink overflow]

  describe DependentsBenefits::PdfFill::Filler, type: :model do
    context "form #{form_id}", run_at: run_at || '2017-07-25 00:00:00 -0400' do
      let(:input_data_fixture_dir) do
        options[:input_data_fixture_dir] || "modules/dependents_benefits/spec/fixtures/pdf_fill/#{form_id}"
      end
      let(:output_pdf_fixture_dir) do
        options[:output_pdf_fixture_dir] || "modules/dependents_benefits/spec/fixtures/pdf_fill/#{form_id}"
      end

      test_data_types.each do |type|
        context "with #{type} test data" do
          let(:form_data) do
            return get_fixture_absolute("#{input_data_fixture_dir}/#{type}") unless options[:use_vets_json_schema]

            schema = "#{form_id.upcase}-#{type.upcase}"
            VetsJsonSchema::EXAMPLES.fetch(schema)
          end

          let(:saved_claim) do
            claim = create(factory)
            claim.update(form: form_data.to_json)
            # refresh claim to reset instance methods like parsed_form
            SavedClaim.find(claim.id)
          end

          before do
            allow(Flipper).to receive(:enabled?).with(anything).and_call_original
            allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(false)
            if type == 'pension_overflow'
              allow(Flipper).to receive(:enabled?).with(:va_dependents_net_worth_and_pension).and_return(true)
            else
              allow(Flipper).to receive(:enabled?).with(:va_dependents_net_worth_and_pension).and_return(false)
            end
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

            fixture_pdf_base = "#{output_pdf_fixture_dir}/#{type}"
            extras_redesign = options[:fill_options] && options[:fill_options][:extras_redesign]

            if type == 'overflow'
              extras_path = the_extras_generator.generate

              fixture_pdf = fixture_pdf_base + (extras_redesign ? '_redesign_extras.pdf' : '_extras.pdf')
              expect(extras_path).to match_file_exactly(fixture_pdf)

              File.delete(extras_path)
            end

            fixture_pdf = fixture_pdf_base + (extras_redesign ? '_redesign.pdf' : '.pdf')
            # Ensure that the fixture PDF actually exists as match_pdf_fields will give vague errors
            # (IOError) if the fixture file can't be found
            expect(Pathname.new(fixture_pdf)).to exist
            expect(file_path).to match_pdf_fields(fixture_pdf)

            File.delete(file_path)
          end
        end
      end
    end
  end
end
