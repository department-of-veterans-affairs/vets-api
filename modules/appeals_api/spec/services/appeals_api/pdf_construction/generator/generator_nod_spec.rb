# frozen_string_literal: true

# DEVELOPER NOTE: The `match_pdf` matcher only checks against the extracted text of the pdf. It cannot verify things
# like checkboxes being checked/unchecked or radio button selection (We tried. That way madness lies.). You will need
# to manually open the generated pdfs to verify those items are behaving as expected.

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::PdfConstruction::Generator do
  include FixtureHelpers
  include SchemaHelpers

  let(:appeal) { create(:notice_of_disagreement) }

  describe '#generate' do
    it 'returns a pdf path' do
      result = described_class.new(appeal).generate
      expect(result[-4..]).to eq('.pdf')
    end

    context 'Notice Of Disagreement' do
      context 'v1' do
        context 'pdf minimum content verification' do
          let(:notice_of_disagreement) { create(:minimal_notice_of_disagreement, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(notice_of_disagreement).generate
            expected_pdf = fixture_filepath('decision_reviews/v1/pdfs/v1/expected_10182_minimum.pdf')
            expect(generated_pdf).to match_pdf expected_pdf
            FileUtils.rm_f(generated_pdf)
          end
        end

        context 'pdf extra content verification' do
          let(:notice_of_disagreement) { create(:notice_of_disagreement, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(notice_of_disagreement).generate
            expected_pdf = fixture_filepath('decision_reviews/v1/pdfs/v1/expected_10182_extra.pdf')
            expect(generated_pdf).to match_pdf expected_pdf
            FileUtils.rm_f(generated_pdf)
          end
        end
      end

      shared_examples 'shared NOD v2 and v3 generator examples' do |pdf_version|
        let(:generated_pdf) { described_class.new(nod, pdf_version:).generate }
        let(:expected_pdf) { fixture_filepath("decision_reviews/v2/pdfs/#{pdf_version}/#{fixture_name}") }

        after { FileUtils.rm_f(generated_pdf) }

        context 'with required content' do
          let(:fixture_name) { 'expected_10182.pdf' }
          let(:nod) { create(:notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end

        context 'with extra content' do
          let(:fixture_name) { 'expected_10182_extra.pdf' }
          let(:nod) { create(:extra_notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end

        context 'with minimal content' do
          let(:fixture_name) { 'expected_10182_minimal.pdf' }
          let(:nod) { create(:minimal_notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end

        context 'pdf max length content verification' do
          let(:fixture_name) { 'expected_10182_maxlength.pdf' }
          let(:nod) do
            build(:extra_notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') do |appeal|
              appeal.form_data = override_max_lengths(appeal, read_schema('10182.json', 'decision_reviews', 'v2'))
              appeal.auth_headers.merge!(
                {
                  'X-VA-SSN' => 'W' * 9,
                  'X-VA-First-Name' => 'W' * 30,
                  'X-VA-Middle-Initial' => 'W',
                  'X-VA-Last-Name' => 'W' * 40,
                  'X-VA-NonVeteranClaimant-First-Name' => 'W' * 30,
                  'X-VA-NonVeteranClaimant-Middle-Initial' => 'W',
                  'X-VA-NonVeteranClaimant-Last-Name' => 'W' * 40,
                  'X-VA-File-Number' => 'W' * 9,
                  'X-Consumer-Username' => 'W' * 255,
                  'X-Consumer-ID' => 'W' * 255
                }
              )
            end
          end

          # TODO: Try to figure out why the CI runner interprets our expected pdf differently than locally, despite
          #       being visually identical.
          # e.g. on CI, some text is interpreted in a slightly different order or W's are added in odd places.
          it 'generates the expected pdf', skip: 'See TODO' do
            expect(generated_pdf).to match_pdf(expected_pdf)
          end
        end
      end

      context 'v3' do
        include_examples 'shared NOD v2 and v3 generator examples', 'v3'
      end

      context 'v2' do
        include_examples 'shared NOD v2 and v3 generator examples', 'v2'
      end

      context 'feb2025' do
        let(:generated_pdf) { described_class.new(nod, pdf_version: 'feb2025').generate }
        let(:expected_pdf) { fixture_filepath("decision_reviews/v2/pdfs/feb2025/#{fixture_name}") }

        after { FileUtils.rm_f(generated_pdf) }

        include_examples 'shared NOD v2 and v3 generator examples', 'feb2025'

        # Test condition where issues overflow because the issues description is too long
        # to fit on the form
        context 'issues description length overflow' do
          let(:fixture_name) { 'expected_10182_min_issues_desc_overflow.pdf' }
          let(:nod) { create(:min_nod_v2_issues_length_overflow, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end

        # Test condition where issues overflow because the issues disagreement area is too long
        # to fit on the form
        context 'issues disagreement area length overflow' do
          let(:fixture_name) { 'expected_10182_min_issues_area_overflow.pdf' }
          let(:nod) { create(:min_nod_v2_issues_long_disagreement_area, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end

        # Test condition where issues overflow because there are too many to fit on form
        context 'issues count overflow' do
          let(:fixture_name) { 'expected_10182_min_issues_count_overflow.pdf' }
          let(:nod) { create(:min_nod_v2_6_issues, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end

        context 'long rep name overflow' do
          let(:fixture_name) { 'expected_10182_min_rep_name_overflow.pdf' }
          let(:nod) { create(:min_nod_v2_long_rep_name, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end

        context 'long email overflow' do
          let(:fixture_name) { 'expected_10182_min_long_email_overflow.pdf' }
          let(:nod) { create(:min_nod_v2_long_email, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end

        context 'extension request overflow' do
          let(:fixture_name) { 'expected_10182_min_extension_request_overflow.pdf' }
          let(:nod) { create(:min_nod_v2_extension_request, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            expect(generated_pdf).to match_pdf expected_pdf
          end
        end
      end
    end
  end
end
