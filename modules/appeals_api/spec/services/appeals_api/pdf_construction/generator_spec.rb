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
        let(:notice_of_disagreement) { create(:minimal_notice_of_disagreement) }

        it 'generates the expected pdf' do
          Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
          generated_pdf = described_class.new(notice_of_disagreement).generate
          expected_pdf = fixture_filepath('expected_10182_minimum.pdf')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
          Timecop.return
        end
      end

      context 'pdf extra content verification' do
        let(:notice_of_disagreement) { create(:notice_of_disagreement) }

        it 'generates the expected pdf' do
          Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
          generated_pdf = described_class.new(notice_of_disagreement).generate
          expected_pdf = fixture_filepath('expected_10182_extra.pdf')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
          Timecop.return
        end
      end

      context 'extra long preferred email verification' do
        let(:notice_of_disagreement) { create(:notice_of_disagreement) }
        let(:new_email) { Faker::Lorem.characters(number: 255 - 6) + '@a.com' }

        before do
          notice_of_disagreement.form_data['data']['attributes']['veteran']['emailAddressText'] = new_email
          notice_of_disagreement.save!
        end

        it 'places long email addresses onto additional page' do
          Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
          generated_pdf = described_class.new(notice_of_disagreement).generate
          reader = PDF::Reader.new(generated_pdf)
          # Character representation of pdf can be hard to test against, since its layout is converted to line breaks,
          # whitespace, & other special characters in non-intuitive ways. We do our best to work with it, below.
          pages_text = reader.pages.map(&:text)
          expect(pages_text[0]).not_to include new_email[0..40]
          expect(pages_text[0]).to include 'See attached page'
          expect(pages_text[1]).to include 'Preferred Email'
          expect(pages_text[1]).to include new_email[0..40]
          File.delete(generated_pdf) if File.exist?(generated_pdf)
          Timecop.return
        end
      end
    end

    context 'Higher Level Review' do
      let(:higher_level_review) { create(:higher_level_review) }
      let(:extra_higher_level_review) { create(:extra_higher_level_review) }
      let(:minimal_higher_level_review) { create(:minimal_higher_level_review) }

      context 'pdf content verification' do
        it 'generates the expected pdf' do
          Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
          generated_pdf = described_class.new(higher_level_review).generate
          expected_pdf = fixture_filepath('expected_200996.pdf')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
          Timecop.return
        end
      end

      context 'pdf extra content verification' do
        it 'generates the expected pdf' do
          Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
          generated_pdf = described_class.new(extra_higher_level_review).generate
          expected_pdf = fixture_filepath('expected_200996_extra.pdf')
          expect(generated_pdf).to match_pdf expected_pdf
          File.delete(generated_pdf) if File.exist?(generated_pdf)
          Timecop.return
        end
      end

      context 'pdf minimum content verification' do
        it 'generates the expected pdf' do
          Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
          generated_pdf = described_class.new(minimal_higher_level_review).generate
          expected_pdf = fixture_filepath('expected_200996_minimum.pdf')
          expect(generated_pdf).to match_pdf(expected_pdf)
          File.delete(generated_pdf) if File.exist?(generated_pdf)
          Timecop.return
        end
      end

      context 'v2' do
        context 'pdf verification' do
          let(:higher_level_review_v2) { create(:higher_level_review_v2) }

          it 'generates the expected pdf' do
            Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
            generated_pdf = described_class.new(higher_level_review_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_v2.pdf')
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
            Timecop.return
          end
        end

        context 'pdf extra content verification' do
          let(:extra_higher_level_review_v2) { create(:extra_higher_level_review_v2) }

          it 'generates the expected pdf' do
            Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
            generated_pdf = described_class.new(extra_higher_level_review_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_v2_extra.pdf')
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
            Timecop.return
          end
        end

        context 'pdf minimum content verification' do
          let(:minimal_higher_level_review_v2) { create(:minimal_higher_level_review_v2) }

          it "generates a pdf and prints 'USE ADDRESS ON FILE'" do
            Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
            generated_pdf = described_class.new(minimal_higher_level_review_v2, version: 'V2').generate
            expected_pdf = fixture_filepath('expected_200996_minimum_v2.pdf')
            expect(generated_pdf).to match_pdf(expected_pdf)
            File.delete(generated_pdf) if File.exist?(generated_pdf)
            Timecop.return
          end
        end
      end
    end
  end
end
