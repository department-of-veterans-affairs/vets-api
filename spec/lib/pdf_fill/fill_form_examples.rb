RSpec.shared_examples 'a form filler' do |options|
  context "form #{options[:form_id]}" do
    %w[simple kitchen_sink overflow].each do |type|
      context "with #{type} test data" do
        let(:input_data_fixture_dir) { options[:input_data_fixture_dir] || "pdf_fill/#{options[:form_id]}" }
        let(:output_pdf_fixture_dir) { options[:output_pdf_fixture_dir] || "pdf_fill/#{options[:form_id]}" }
        let(:form_data) do
          return get_fixture("#{input_data_fixture_dir}/#{type}") unless options[:use_vets_json_schema]

          schema = "#{form_id.upcase}-#{type.upcase}"
          VetsJsonSchema::EXAMPLES.fetch(schema)
        end
        let(:saved_claim) { create(options[:factory], form: form_data.to_json) }

        it 'fills the form correctly' do
          if type == 'overflow'
            # pdfs_fields_match? only compares based on filled fields, it doesn't read the extras page
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

            expect(
              FileUtils.compare_file(extras_path, "spec/fixtures/#{output_pdf_fixture_dir}/overflow_extras.pdf")
            ).to eq(true)

            File.delete(extras_path)
          end

          expect(
            pdfs_fields_match?(file_path, "spec/fixtures/#{output_pdf_fixture_dir}/#{type}.pdf")
          ).to eq(true)

          File.delete(file_path)
        end
      end
    end
  end
end
