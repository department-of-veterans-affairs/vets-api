# frozen_string_literal: true

require 'rails_helper'

##
# Converts each page of a PDF to images and saves them to the specified output directory.
#
# @param pdf_path [String] The path to the PDF file.
# @param options [Hash] Options for conversion.
#  - :output_dir [String] The directory to save the images. Default is 'tmp/pdfs'.
#   - :test_type [String] A label for the test type. Default is 'simple'.
#   - :start_page [Integer] The starting page number (1-based). Default is 1.
#   - :end_page [Integer] The ending page number (1-based). Default is the last page of the PDF.
#
# @return [Integer] The number of pages processed.
#
def pdf_to_images(pdf_path, options = {})
  output_dir = options[:output_dir] || 'tmp/pdfs'
  test_type = options[:test_type] || 'simple'
  start_page = options[:start_page] || 1

  pdf = MiniMagick::Image.open(pdf_path)

  end_page = options[:end_page] || pdf.pages.size

  test_type += '_fixture' if options[:fixture]
  FileUtils.mkdir_p(output_dir) # Ensure that the output directory exists

  pdf.pages.each_with_index do |page, index|
    next if index + 1 < start_page || index + 1 > end_page

    filename = "#{options[:form_id]}.#{test_type}.page_#{index + 1}.png"

    MiniMagick.convert do |convert|
      convert.density 300
      convert.background 'white'
      convert << page.path
      convert.flatten
      convert.quality 100
      convert << File.join(output_dir, filename)
    end
  end

  end_page - start_page + 1
end

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

  describe PdfFill::Filler, type: :model do
    context "form #{form_id}", run_at: run_at || '2017-07-25 00:00:00 -0400' do
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
              claim = create(factory, form: form_data.to_json)
              claim.update(form_id:) if claim.has_attribute?(:form_id)
              claim
            end
          end

          before do
            allow(Flipper).to receive(:enabled?).with(anything).and_call_original
            allow(Flipper).to receive(:enabled?).with(:saved_claim_pdf_overflow_tracking).and_return(false)
            # this is a temporary disabling of the pension flipper while pension work is still in progress
            allow(Flipper).to receive(:enabled?).with(:va_dependents_net_worth_and_pension).and_return(false)
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

            # For now this should only run in development to avoid slowing down test suite in CI
            if options[:use_ocr] && ENV['CI'].blank?
              start_page = options[:ocr_start_page] || 1
              end_page = options[:ocr_end_page] || nil

              ocr_options = {
                test_type: type,
                form_id:,
                start_page:,
                end_page:,
                fixture: false
              }

              fixture_ocr_options = ocr_options.clone.merge(fixture: true)

              num_pages = pdf_to_images(file_path, ocr_options)
              fixture_num_pages = pdf_to_images(fixture_pdf, fixture_ocr_options)
              expect(num_pages).to eq(fixture_num_pages)

              ((start_page - 1)...end_page).each do |index|
                image_path = File.join('tmp/pdfs', "#{form_id}.#{type}.page_#{index + 1}.png")
                fixture_path = File.join('tmp/pdfs', "#{form_id}.#{type}_fixture.page_#{index + 1}.png")
                begin
                  file_as_string = RTesseract.new(image_path).to_s
                  fixture_as_string = RTesseract.new(fixture_path).to_s
                  expect(file_as_string).to eq(fixture_as_string)
                ensure
                  File.delete(image_path, fixture_path) if File.exist?(image_path) || File.exist?(fixture_path)
                end
              end
            end

            File.delete(file_path)
          end
        end
      end
    end
  end
end
