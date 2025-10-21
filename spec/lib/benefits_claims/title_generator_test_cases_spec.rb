# frozen_string_literal: true

require 'rails_helper'
require 'benefits_claims/title_generator'
require 'test_helpers/title_generator_test_claims'

RSpec.describe BenefitsClaims::TitleGenerator do
  describe 'test cases from TitleGeneratorTestClaims' do
    let(:test_cases) { TitleGeneratorTestClaims.all_test_cases }
    let(:expected_results) { TitleGeneratorTestClaims.expected_results }

    test_cases = TitleGeneratorTestClaims.all_test_cases
    expected_results = TitleGeneratorTestClaims.expected_results

    test_cases.each do |test_case|
      test_id = test_case['id']
      expected = expected_results[test_id]
      claim_type = test_case.dig('attributes', 'claimType')
      claim_type_code = test_case.dig('attributes', 'claimTypeCode')

      context "for test case: #{test_id}" do
        it "generates correct titles for claimType='#{claim_type}' and claimTypeCode='#{claim_type_code}'" do
          result = described_class.generate_titles(claim_type, claim_type_code)

          expect(result[:display_title]).to eq(expected[:display_title]),
            "Expected display_title to be '#{expected[:display_title]}' but got '#{result[:display_title]}'"

          expect(result[:claim_type_base]).to eq(expected[:claim_type_base]),
            "Expected claim_type_base to be '#{expected[:claim_type_base]}' but got '#{result[:claim_type_base]}'"
        end
      end
    end

    describe 'update_claim_title method' do
      test_cases.each do |test_case|
        test_id = test_case['id']
        expected = expected_results[test_id]
        claim_type = test_case.dig('attributes', 'claimType')
        claim_type_code = test_case.dig('attributes', 'claimTypeCode')

        context "for test case: #{test_id}" do
          it "updates claim attributes correctly for claimType='#{claim_type}' and claimTypeCode='#{claim_type_code}'" do
            claim = Marshal.load(Marshal.dump(test_case)) # Deep copy

            described_class.update_claim_title(claim)

            expect(claim.dig('attributes', 'displayTitle')).to eq(expected[:display_title]),
              "Expected displayTitle to be '#{expected[:display_title]}' but got '#{claim.dig('attributes', 'displayTitle')}'"

            expect(claim.dig('attributes', 'claimTypeBase')).to eq(expected[:claim_type_base]),
              "Expected claimTypeBase to be '#{expected[:claim_type_base]}' but got '#{claim.dig('attributes', 'claimTypeBase')}'"
          end
        end
      end
    end

    describe 'summary statistics' do
      it 'tests all expected results' do
        expect(test_cases.length).to eq(expected_results.length),
          "Mismatch: #{test_cases.length} test cases but #{expected_results.length} expected results"
      end

      it 'has no missing test cases' do
        test_ids = test_cases.map { |tc| tc['id'] }
        expected_ids = expected_results.keys

        missing = expected_ids - test_ids
        expect(missing).to be_empty, "Missing test cases: #{missing.join(', ')}"
      end

      it 'has no extra test cases' do
        test_ids = test_cases.map { |tc| tc['id'] }
        expected_ids = expected_results.keys

        extra = test_ids - expected_ids
        expect(extra).to be_empty, "Extra test cases without expected results: #{extra.join(', ')}"
      end

      it 'covers all priority levels' do
        # Extract test case priorities from their descriptions
        priority_1_codes = test_cases.select do |tc|
          tc['id'].include?('dependency') ||
          tc['id'].include?('pension') ||
          tc['id'].include?('dic') ||
          tc['id'].include?('debt-validation') ||
          tc['id'].include?('in-service-death') ||
          tc['id'].include?('dependency-verification')
        end

        priority_2_cases = test_cases.select { |tc| tc['id'].include?('death-special-case') }
        priority_3_cases = test_cases.select { |tc| tc['id'].include?('default') }
        priority_4_cases = test_cases.select { |tc| tc['id'].include?('nil-fallback') }
        edge_cases = test_cases.select { |tc| tc['id'].include?('unknown') || tc['id'].include?('empty') || tc['id'].include?('mixed') }

        expect(priority_1_codes.length).to be > 0, 'Should have Priority 1 (code mapping) test cases'
        expect(priority_2_cases.length).to be > 0, 'Should have Priority 2 (special case) test cases'
        expect(priority_3_cases.length).to be > 0, 'Should have Priority 3 (default generation) test cases'
        expect(priority_4_cases.length).to be > 0, 'Should have Priority 4 (nil fallback) test cases'
        expect(edge_cases.length).to be > 0, 'Should have edge case test cases'
      end
    end
  end
end
