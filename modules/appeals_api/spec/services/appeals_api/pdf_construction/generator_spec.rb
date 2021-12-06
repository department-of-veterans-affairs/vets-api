# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

describe AppealsApi::PdfConstruction::Generator do
  include FixtureHelpers

  let(:appeal) { create(:notice_of_disagreement) }

  describe '#generate' do
    it 'returns a pdf path' do
      result = described_class.new(appeal).generate
      expect(result[-4..]).to eq('.pdf')
    end

    context 'Notice Of Disagreement' do
      context 'pdf minimum content verification' do
        let(:notice_of_disagreement) { create(:minimal_notice_of_disagreement, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(notice_of_disagreement).generate
          expected_pdf = fixture_filepath('expected_10182_minimum.pdf')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf extra content verification' do
        let(:notice_of_disagreement) { create(:notice_of_disagreement, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(notice_of_disagreement).generate
          expected_pdf = fixture_filepath('expected_10182_extra.pdf')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end
    end

    context 'Higher Level Review' do
      let(:higher_level_review) { create(:higher_level_review, created_at: '2021-02-03T14:15:16Z') }
      let(:extra_higher_level_review) { create(:extra_higher_level_review, created_at: '2021-02-03T14:15:16Z') }
      let(:minimal_higher_level_review) { create(:minimal_higher_level_review, created_at: '2021-02-03T14:15:16Z') }

      context 'pdf content verification' do
        it 'generates the expected pdf' do
          generated_pdf = described_class.new(higher_level_review).generate
          expected_pdf = fixture_filepath('expected_200996.pdf')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf extra content verification' do
        it 'generates the expected pdf' do
          generated_pdf = described_class.new(extra_higher_level_review).generate
          expected_pdf = fixture_filepath('expected_200996_extra.pdf')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf minimum content verification' do
        it 'generates the expected pdf' do
          generated_pdf = described_class.new(minimal_higher_level_review).generate
          expected_pdf = fixture_filepath('expected_200996_minimum.pdf')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'v2' do
        context 'pdf verification' do
          let(:higher_level_review_v2) { create(:higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(higher_level_review_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_v2.pdf')
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf extra content verification' do
          let(:extra_hlr_v2) { create(:extra_higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(extra_hlr_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_v2_extra.pdf')
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf minimum content verification' do
          let(:minimal_hlr_v2) { create(:minimal_higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(minimal_hlr_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_minimum_v2.pdf')
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end
      end
    end

    context 'Supplemental Claim' do
      context 'pdf verification' do
        let(:supplemental_claim) { create(:supplemental_claim, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(supplemental_claim, version: 'V2').generate
          expected_pdf = fixture_filepath('expected_200995.pdf')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf extra content verification' do
        let(:extra_supplemental_claim) { create(:extra_supplemental_claim, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(extra_supplemental_claim, version: 'V2').generate
          expected_pdf = fixture_filepath('expected_200995_extra.pdf')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end
    end
  end
end
