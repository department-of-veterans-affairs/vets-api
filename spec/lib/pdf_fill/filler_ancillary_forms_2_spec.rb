# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'
require 'lib/pdf_fill/fill_form_examples'

# Lighter ancillary forms split from filler_spec.rb for CI parallelization.
describe PdfFill::Filler, type: :model do
  describe '#fill_ancillary_form (lighter forms)', run_at: '2017-07-25 00:00:00 -0400' do
    %w[22-10215a 21-4142 28-8832 22-10275 22-10272 26-1880 21-0781a 28-1900 5655 22-10216
       22-1919 22-0810].each do |form_id|
      context "form #{form_id}" do
        form_types = %w[simple kitchen_sink overflow].map { |type| [type, false, false] }
        form_types.each do |type, extras_redesign, show_jumplinks|
          context "with type=#{type} extras_redesign=#{extras_redesign} show_jumplinks=#{show_jumplinks}" do
            let(:form_data) do
              get_fixture("pdf_fill/#{form_id}/#{type}")
            end

            it 'fills the form correctly' do
              if type == 'overflow'
                the_extras_generator = nil
                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              # this is only for 21-674-V2 but it passes in the extras hash. passing nil for all other scenarios
              student = form_id == '21-674-V2' ? form_data['dependents_application']['student_information'][0] : nil

              expect(described_class).to receive(:stamp_form).once.and_call_original if extras_redesign

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id,
                                                              { extras_redesign:, student:, show_jumplinks: })

              fixture_pdf_base = "spec/fixtures/pdf_fill/#{form_id}/#{type}"

              if type == 'overflow'
                extras_path = the_extras_generator.generate
                fixture_pdf = fixture_pdf_base + overflow_file_suffix(extras_redesign, show_jumplinks)
                expect(extras_path).to match_file_exactly(fixture_pdf)

                File.delete(extras_path)
              end

              fixture_pdf = fixture_pdf_base + (extras_redesign ? '_redesign.pdf' : '.pdf')
              expect(file_path).to match_pdf_fields(fixture_pdf)

              File.delete(file_path)
            end
          end
        end
      end
    end
  end
end
