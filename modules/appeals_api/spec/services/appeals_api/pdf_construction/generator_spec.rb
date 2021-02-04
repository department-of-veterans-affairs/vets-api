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
    end
  end
end
