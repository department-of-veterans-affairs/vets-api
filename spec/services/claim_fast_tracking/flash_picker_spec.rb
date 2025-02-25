# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimFastTracking::FlashPicker do
  subject { described_class }

  describe '#als?' do
    context 'when testing for ALS' do
      context 'when the disabilities is empty' do
        let(:disabilities) { [] }

        it 'returns an empty array' do
          expect(subject.als?(disabilities)).to be(false)
        end
      end

      context 'when the disabilities does not contain ALS' do
        let(:disabilities) { [{ 'name' => 'Tinnitus', 'diagnosticCode' => 6260 }] }

        it 'returns false' do
          expect(subject.als?(disabilities)).to be(false)
        end
      end

      context 'when the disability name exactly matches any of the ALS_TERMS' do
        described_class::ALS_MATCH_TERMS.each do |term|
          it "returns true for term #{term}" do
            expect(subject.als?([{ 'name' => term }])).to be(true)
          end
        end
      end

      context 'when the disability name has partial match' do
        [
          { condition: 'amyotrophic lateral sclerosis', reason: 'full name' },
          { condition: '(als)', reason: 'acronym only in parentheses' },
          {
            condition: 'amyotrophic lateral sclerosis with lower extremity weakness, abnormal speech and abnormal gait',
            reason: 'full name with symptoms'
          },
          { condition: 'als amyotrophic lateral sclerosis', reason: 'full name with acronym on left' },
          { condition: 'als (amyotrophic lateral sclerosis)', reason: 'full name in parentheses with acronym on left' },
          { condition: 'als amyotrophic lateral sclerosis', reason: 'full name with acronym on left' },
          { condition: '(als) amyotrophic lateral sclerosis', reason: 'full name with acronym on left in parentheses' },
          { condition: 'amyotrophic lateral sclerosis als', reason: 'full name with acronym on right' },
          { condition: '(amyotrophic lateral sclerosis) als',
            reason: 'full name in parentheses with acronym on right' },
          { condition: 'amyotrophic lateral sclerosis (als)',
            reason: 'full name with acronym on right in parentheses' },
          { condition: 'amyotropic lateril scerolses (als)',
            reason: 'full name with several letter typo and acronym in parentheses' }
        ].each do |test_case|
          it "returns true for term #{test_case[:reason]}" do
            disabilities = [{ 'name' => test_case[:condition] }]
            expect(subject.als?(disabilities)).to be(true)
          end
        end
      end

      context 'when the disabilities contains a fuzzy match' do
        [
          { condition: 'amyotrophic lateral scleroses', reason: 'Pluralization error' },
          { condition: 'Amyothrophic lateral sclerosis', reason: 'Minor typo' },
          { condition: 'amyotrophic lateral sclerosiss', reason: 'Minor double letter typo' },
          { condition: 'amyotropic lareral sclerosiss', reason: 'several letter typo' },
          { condition: 'amyotrophic lateral scelrosis', reason: 'Phonetic misspelling' },
          { condition: 'lou gherig disease', reason: 'Phonetic misspelling of Gehrig' },
          { condition: 'lou gehrigs desease', reason: 'Double typo' },
          { condition: 'lou gehrigs desase', reason: 'Phonetic error' },
          { condition: "lou gehrig's disease", reason: 'Included Apostrophe with disease' },
          { condition: "lou gehrig'", reason: 'Included Apostrophe without s' },
          { condition: 'lou gehrig', reason: 'Missing possessive "s"' }
        ].each do |test_case|
          it "returns true for term with #{test_case[:reason]}" do
            disabilities = [{ 'name' => test_case[:condition] }]
            expect(subject.als?(disabilities)).to be(true)
          end
        end
      end

      context 'when the disabilities does not contains any fuzzy match' do
        [
          { condition: 'ALT', reason: 'wrong acronym but too small to fuzzy match' },
          { condition: 'sclerosis disease', reason: 'Too vague' },
          { condition: 'Lou diseases', reason: 'Doesn’t specify' },
          { condition: 'lateral disease', reason: 'Partial match with missing context' },
          { condition: 'neuro disease', reason: 'Different condition entirely' }
        ].each do |test_case|
          it "returns false for term with #{test_case[:reason]}" do
            disabilities = [{ 'name' => test_case[:condition] }]
            expect(subject.als?(disabilities)).to be(false)
          end
        end
      end
    end
  end
end
