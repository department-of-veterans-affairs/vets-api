# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

describe PdfFill::Filler, type: :model do
  include SchemaMatchers

  describe '#combine_extras' do
    subject do
      described_class.combine_extras(old_file_path, extras_generator)
    end

    let(:extras_generator) { double }
    let(:old_file_path) { 'tmp/pdfs/file_path.pdf' }

    context 'when extras_generator doesnt have text' do
      it 'returns the old_file_path' do
        expect(extras_generator).to receive(:text?).once.and_return(false)

        expect(subject).to eq(old_file_path)
      end
    end

    context 'when extras_generator has text' do
      before do
        expect(extras_generator).to receive(:text?).once.and_return(true)
      end

      it 'generates extras and combine the files' do
        file_path = 'tmp/pdfs/file_path_final.pdf'
        expect(extras_generator).to receive(:generate).once.and_return('extras.pdf')
        expect(described_class::PDF_FORMS).to receive(:cat).once.with(
          old_file_path,
          'extras.pdf',
          file_path
        )
        expect(File).to receive(:delete).once.with('extras.pdf')
        expect(File).to receive(:delete).once.with(old_file_path)

        expect(subject).to eq(file_path)
      end
    end
  end

  describe '#fill_form', run_at: '2017-07-25 00:00:00 -0400' do
    [
      {
        form_id: '21P-530',
        factory: :burial_claim
      },
      {
        form_id: '21P-527EZ',
        factory: :pension_claim
      },
      {
        form_id: '10-10CG',
        factory: :caregivers_assistance_claim,
        fixture_path: 'pdf_fill/10-10CG/unsigned',
        fill_options: {
          sign: false
        }
      },
      {
        form_id: '10-10CG',
        factory: :caregivers_assistance_claim,
        fixture_path: 'pdf_fill/10-10CG/signed',
        fill_options: {
          sign: true
        }
      },
      {
        form_id: '686C-674',
        factory: :dependency_claim
      }
    ].each do |form_id:, factory:, **options|
      context "form #{form_id}" do
        %w[simple kitchen_sink overflow].each do |type|
          context "with #{type} test data" do
            let(:fixture_path) do
              options[:fixture_path] || "pdf_fill/#{form_id}"
            end

            let(:form_data) do
              get_fixture("#{fixture_path}/#{type}")
            end

            let(:saved_claim) do
              create(factory, form: form_data.to_json)
            end

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
                  FileUtils.compare_file(extras_path, "spec/fixtures/#{fixture_path}/overflow_extras.pdf")
                ).to eq(true)

                File.delete(extras_path)
              end

              expect(
                pdfs_fields_match?(file_path, "spec/fixtures/#{fixture_path}/#{type}.pdf")
              ).to eq(true)

              File.delete(file_path)
            end
          end
        end
      end
    end
  end

  describe '#fill_ancillary_form', run_at: '2017-07-25 00:00:00 -0400' do
    %w[21-4142 21-0781a 21-0781 21-8940 28-8832].each do |form_id|
      context "form #{form_id}" do
        %w[simple kitchen_sink overflow].each do |type|
          context "with #{type} test data" do
            let(:form_data) do
              get_fixture("pdf_fill/#{form_id}/#{type}")
            end

            it 'fills the form correctly' do
              if type == 'overflow'
                # pdfs_fields_match? only compares based on filled fields, it doesn't read the extras page
                the_extras_generator = nil
                expect(described_class).to receive(:combine_extras).once do |old_file_path, extras_generator|
                  the_extras_generator = extras_generator
                  old_file_path
                end
              end

              file_path = described_class.fill_ancillary_form(form_data, 1, form_id)

              if type == 'overflow'
                extras_path = the_extras_generator.generate

                expect(
                  FileUtils.compare_file(extras_path, "spec/fixtures/pdf_fill/#{form_id}/overflow_extras.pdf")
                ).to eq(true)

                File.delete(extras_path)
              end

              expect(
                pdfs_fields_match?(file_path, "spec/fixtures/pdf_fill/#{form_id}/#{type}.pdf")
              ).to eq(true)

              File.delete(file_path)
            end
          end
        end
      end
    end
  end
end
