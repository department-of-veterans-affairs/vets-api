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
          expected_pdf = fixture_filepath('expected_10182_minimum.pdf', version: 'v1')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf extra content verification' do
        let(:notice_of_disagreement) { create(:notice_of_disagreement, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(notice_of_disagreement).generate
          expected_pdf = fixture_filepath('expected_10182_extra.pdf', version: 'v1')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'v2' do
        context 'pdf content verification' do
          let(:nod_v2) { create(:notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(nod_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_10182.pdf', version: 'v2')
            expect(generated_pdf).to match_pdf expected_pdf
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf extra content verification' do
          let(:extra_nod_v2) { create(:extra_notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            data = extra_nod_v2.form_data
            data['data']['attributes']['extensionReason'] = 'W' * 2300
            extra_nod_v2.form_data = data

            generated_pdf = described_class.new(extra_nod_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_10182_extra.pdf', version: 'v2')
            expect(generated_pdf).to match_pdf expected_pdf
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf minimal content verification' do
          let(:minimal_nod_v2) { create(:minimal_notice_of_disagreement_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(minimal_nod_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_10182_minimal.pdf', version: 'v2')
            expect(generated_pdf).to match_pdf expected_pdf
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
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
          expected_pdf = fixture_filepath('expected_200996.pdf', version: 'v1')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf extra content verification' do
        it 'generates the expected pdf' do
          generated_pdf = described_class.new(extra_higher_level_review).generate
          expected_pdf = fixture_filepath('expected_200996_extra.pdf', version: 'v1')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf minimum content verification' do
        it 'generates the expected pdf' do
          generated_pdf = described_class.new(minimal_higher_level_review).generate
          expected_pdf = fixture_filepath('expected_200996_minimum.pdf', version: 'v1')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'v2' do
        context 'pdf verification' do
          let(:higher_level_review_v2) { create(:higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(higher_level_review_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996.pdf', version: 'v2')
            # Manually test changes to radio buttons
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf extra content verification' do
          let(:extra_hlr_v2) { create(:extra_higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(extra_hlr_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_extra.pdf', version: 'v2')
            # Manually test changes to radio buttons
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'pdf minimum content verification' do
          let(:minimal_hlr_v2) { create(:minimal_higher_level_review_v2, created_at: '2021-02-03T14:15:16Z') }

          it 'generates the expected pdf' do
            generated_pdf = described_class.new(minimal_hlr_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_minimum.pdf', version: 'v2')
            # Manually test changes to radio buttons
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end
        end

        context 'special character verification' do
          it 'allows certain typography characters into Windows-1252' do
            hlr = build(:minimal_higher_level_review)
            hlr.form_data['included'][0]['attributes']['issue'] = 'Smartquotes: “”‘’'
            hlr.save!
            generated_pdf = described_class.new(hlr, version: 'V2').generate
            generated_reader = PDF::Reader.new(generated_pdf)
            expect(generated_reader.pages[1].text).to include 'Smartquotes: “”‘’'
            File.delete(generated_pdf) if File.exist?(generated_pdf)
          end

          it 'removes characters that fall outsize Windows-1252 charset that cannot be downgraded' do
            hlr = build(:minimal_higher_level_review)
            hlr.form_data['included'][0]['attributes']['issue'] = '∑mer allergies'
            hlr.save!
            generated_pdf = described_class.new(hlr, version: 'V2').generate
            generated_reader = PDF::Reader.new(generated_pdf)
            expect(generated_reader.pages[1].text).to include 'mer allergies'
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
          expected_pdf = fixture_filepath('expected_200995.pdf', version: 'v2')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end

      context 'pdf extra content verification' do
        let(:extra_supplemental_claim) { create(:extra_supplemental_claim, created_at: '2021-02-03T14:15:16Z') }

        it 'generates the expected pdf' do
          generated_pdf = described_class.new(extra_supplemental_claim, version: 'V2').generate
          expected_pdf = fixture_filepath('expected_200995_extra.pdf', version: 'v2')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
        end
      end
    end
  end
end
