# frozen_string_literal: true

require 'rails_helper'

require 'benefits_claims/title_generator'

RSpec.describe BenefitsClaims::TitleGenerator do
  describe '.generate_titles' do
    context 'with specific claim type code override' do
      context 'with dependency codes' do
        BenefitsClaims::TitleGenerator::DEPENDENCY_CODES.each do |code|
          it "returns dependency title for code #{code}" do
            result = described_class.generate_titles('Some Type', code)

            expect(result).to eq({
                                   display_title: 'Request to add or remove a dependent',
                                   claim_type_base: 'request to add or remove a dependent'
                                 })
          end
        end
      end

      context 'with veterans pension codes' do
        BenefitsClaims::TitleGenerator::VETERANS_PENSION_CODES.each do |code|
          it "returns veterans pension title for code #{code}" do
            result = described_class.generate_titles('Some Type', code)

            expect(result).to eq({
                                   display_title: 'Claim for Veterans Pension',
                                   claim_type_base: 'Veterans Pension claim'
                                 })
          end
        end
      end

      context 'with survivors pension codes' do
        BenefitsClaims::TitleGenerator::SURVIVORS_PENSION_CODES.each do |code|
          it "returns survivors pension title for code #{code}" do
            result = described_class.generate_titles('Some Type', code)

            expect(result).to eq({
                                   display_title: 'Claim for Survivors Pension',
                                   claim_type_base: 'Survivors Pension claim'
                                 })
          end
        end
      end

      context 'with DIC codes' do
        BenefitsClaims::TitleGenerator::DIC_CODES.each do |code|
          it "returns DIC title for code #{code}" do
            result = described_class.generate_titles('Some Type', code)

            expect(result).to eq({
                                   display_title: 'Claim for Dependency and Indemnity Compensation',
                                   claim_type_base: 'Dependency and Indemnity Compensation claim'
                                 })
          end
        end
      end

      context 'with generic pension codes' do
        BenefitsClaims::TitleGenerator::GENERIC_PENSION_CODES.each do |code|
          it "returns generic pension title for code #{code}" do
            result = described_class.generate_titles('Some Type', code)

            expect(result).to eq({
                                   display_title: 'Claim for pension',
                                   claim_type_base: 'pension claim'
                                 })
          end
        end
      end

      context 'with claimant substitution codes' do
        BenefitsClaims::TitleGenerator::CLAIMANT_SUBSTITUTION_CODES.each do |code|
          it "returns substitution title for code #{code}" do
            result = described_class.generate_titles('Some Type', code)

            expect(result).to eq({
                                   display_title: 'Request for substitution of claimant on record',
                                   claim_type_base: 'request for substitution of claimant on record'
                                 })
          end
        end
      end

      context 'with disability compensation codes' do
        BenefitsClaims::TitleGenerator::DISABILITY_COMPENSATION_CODES.each do |code|
          it "returns disability compensation title for code #{code}" do
            result = described_class.generate_titles('Some Type', code)

            expect(result).to eq({
                                   display_title: 'Claim for disability compensation',
                                   claim_type_base: 'disability compensation claim'
                                 })
          end
        end
      end
    end

    context 'with special case transformations' do
      it 'returns death/burial title for Death claim type' do
        result = described_class.generate_titles('Death', nil)

        expect(result).to eq({
                               display_title: 'Claim for expenses related to death or burial',
                               claim_type_base: 'expenses related to death or burial claim'
                             })
      end

      it 'prioritizes code mapping over special case transformation' do
        result = described_class.generate_titles('Death', '130DPNDCY')

        expect(result).to eq({
                               display_title: 'Request to add or remove a dependent',
                               claim_type_base: 'request to add or remove a dependent'
                             })
      end
    end

    context 'with default title generation' do
      it 'generates default title for regular claim type' do
        result = described_class.generate_titles('Disability', nil)

        expect(result).to eq({
                               display_title: 'Claim for disability',
                               claim_type_base: 'disability claim'
                             })
      end

      it 'handles mixed case claim types' do
        result = described_class.generate_titles('COMPENSATION', nil)

        expect(result).to eq({
                               display_title: 'Claim for compensation',
                               claim_type_base: 'compensation claim'
                             })
      end

      it 'handles claim types with spaces' do
        result = described_class.generate_titles('Burial Allowance', nil)

        expect(result).to eq({
                               display_title: 'Claim for burial allowance',
                               claim_type_base: 'burial allowance claim'
                             })
      end
    end

    context 'with missing data' do
      it 'returns nil values when both claim type and code are nil' do
        result = described_class.generate_titles(nil, nil)

        expect(result).to eq({
                               display_title: 'Claim for disability compensation',
                               claim_type_base: 'disability compensation claim'
                             })
      end

      it 'returns nil values when both claim type and code are empty strings' do
        result = described_class.generate_titles('', '')

        expect(result).to eq({
                               display_title: 'Claim for disability compensation',
                               claim_type_base: 'disability compensation claim'
                             })
      end

      it 'returns nil values when claim type is blank and code is unknown' do
        result = described_class.generate_titles('', 'UNKNOWN_CODE')

        expect(result).to eq({
                               display_title: 'Claim for disability compensation',
                               claim_type_base: 'disability compensation claim'
                             })
      end

      it 'generates default title when claim type is present but code is unknown' do
        result = described_class.generate_titles('Education', 'UNKNOWN_CODE')

        expect(result).to eq({
                               display_title: 'Claim for education',
                               claim_type_base: 'education claim'
                             })
      end
    end

    context 'edge cases and validations' do
      it 'handles whitespace-only claim type' do
        result = described_class.generate_titles('   ', nil)

        expect(result).to eq({
                               display_title: 'Claim for disability compensation',
                               claim_type_base: 'disability compensation claim'
                             })
      end

      it 'trims whitespace from claim type' do
        result = described_class.generate_titles('  Disability  ', nil)

        expect(result).to eq({
                               display_title: 'Claim for disability',
                               claim_type_base: 'disability claim'
                             })
      end

      it 'handles numeric claim types' do
        result = described_class.generate_titles('123', nil)

        expect(result).to eq({
                               display_title: 'Claim for 123',
                               claim_type_base: '123 claim'
                             })
      end

      it 'handles special characters in claim type' do
        result = described_class.generate_titles('Claim-Type/Special', nil)

        expect(result).to eq({
                               display_title: 'Claim for claim-type/special',
                               claim_type_base: 'claim-type/special claim'
                             })
      end
    end
  end

  describe '.update_claim_title' do
    let(:claim) { { 'attributes' => {} } }

    context 'with claim type code' do
      it 'updates claim with dependency title when claim type code is present' do
        claim['attributes']['claimType'] = 'Some Type'
        claim['attributes']['claimTypeCode'] = '130DPNDCY'

        described_class.update_claim_title(claim)

        expect(claim['attributes']['displayTitle']).to eq('Request to add or remove a dependent')
        expect(claim['attributes']['claimTypeBase']).to eq('request to add or remove a dependent')
      end

      it 'updates claim with disability compensation title when disability compensation code is present' do
        claim['attributes']['claimType'] = 'Compensation'
        claim['attributes']['claimTypeCode'] = '020NEW'

        described_class.update_claim_title(claim)

        expect(claim['attributes']['displayTitle']).to eq('Claim for disability compensation')
        expect(claim['attributes']['claimTypeBase']).to eq('disability compensation claim')
      end
    end

    context 'with special case claim type' do
      it 'updates claim with death/burial title for Death claim type' do
        claim['attributes']['claimType'] = 'Death'
        claim['attributes']['claimTypeCode'] = nil

        described_class.update_claim_title(claim)

        expect(claim['attributes']['displayTitle']).to eq('Claim for expenses related to death or burial')
        expect(claim['attributes']['claimTypeBase']).to eq('expenses related to death or burial claim')
      end
    end

    context 'with regular claim type' do
      it 'updates claim with default title for regular claim type' do
        claim['attributes']['claimType'] = 'Disability'
        claim['attributes']['claimTypeCode'] = nil

        described_class.update_claim_title(claim)

        expect(claim['attributes']['displayTitle']).to eq('Claim for disability')
        expect(claim['attributes']['claimTypeBase']).to eq('disability claim')
      end
    end

    context 'with missing data' do
      it 'updates claim with default values when no data is present' do
        claim['attributes']['claimType'] = nil
        claim['attributes']['claimTypeCode'] = nil

        described_class.update_claim_title(claim)

        expect(claim['attributes']['displayTitle']).to eq('Claim for disability compensation')
        expect(claim['attributes']['claimTypeBase']).to eq('disability compensation claim')
      end
    end

    context 'with nested attributes structure' do
      it 'handles deeply nested attributes' do
        claim = {
          'attributes' => {
            'claimType' => 'Veterans Pension',
            'claimTypeCode' => nil,
            'other_field' => 'should remain unchanged'
          }
        }

        described_class.update_claim_title(claim)

        expect(claim['attributes']['displayTitle']).to eq('Claim for veterans pension')
        expect(claim['attributes']['claimTypeBase']).to eq('veterans pension claim')
        expect(claim['attributes']['other_field']).to eq('should remain unchanged')
      end
    end

    context 'with missing attributes key' do
      it 'handles claim without attributes gracefully' do
        empty_claim = {}

        expect { described_class.update_claim_title(empty_claim) }.not_to raise_error
      end
    end

    context 'with nil claim' do
      it 'handles nil claim gracefully' do
        expect { described_class.update_claim_title(nil) }.not_to raise_error
      end
    end
  end

  describe 'constants and data integrity' do
    describe 'DEPENDENCY_CODES' do
      it 'contains the expected number of codes' do
        expect(BenefitsClaims::TitleGenerator::DEPENDENCY_CODES.length).to eq(45)
      end

      it 'contains unique codes' do
        codes = BenefitsClaims::TitleGenerator::DEPENDENCY_CODES
        expect(codes.uniq.length).to eq(codes.length)
      end

      it 'contains only string values' do
        codes = BenefitsClaims::TitleGenerator::DEPENDENCY_CODES
        expect(codes.all? { |code| code.is_a?(String) }).to be true
      end
    end

    describe 'VETERANS_PENSION_CODES' do
      it 'contains the expected codes' do
        expected = %w[180AILP 180ORGPENPMC 180ORGPEN]
        expect(BenefitsClaims::TitleGenerator::VETERANS_PENSION_CODES).to eq(expected)
      end
    end

    describe 'SURVIVORS_PENSION_CODES' do
      it 'contains the expected codes' do
        expected = %w[190ORGDPN 190ORGDPNPMC 190AID 140ISD 687NRPMC]
        expect(BenefitsClaims::TitleGenerator::SURVIVORS_PENSION_CODES).to eq(expected)
      end
    end

    describe 'DIC_CODES' do
      it 'contains the expected codes' do
        expected = %w[290DICEDPMC 020SMDICPMC 020IRDICPMC]
        expect(BenefitsClaims::TitleGenerator::DIC_CODES).to eq(expected)
      end
    end

    describe 'CLAIMANT_SUBSTITUTION_CODES' do
      it 'contains the expected codes' do
        expected = %w[290SCNR 290SCPMC 290SCR]
        expect(BenefitsClaims::TitleGenerator::CLAIMANT_SUBSTITUTION_CODES).to eq(expected)
      end

      it 'contains unique codes' do
        codes = BenefitsClaims::TitleGenerator::CLAIMANT_SUBSTITUTION_CODES
        expect(codes.uniq.length).to eq(codes.length)
      end

      it 'contains only string values' do
        codes = BenefitsClaims::TitleGenerator::CLAIMANT_SUBSTITUTION_CODES
        expect(codes.all? { |code| code.is_a?(String) }).to be true
      end
    end

    describe 'DISABILITY_COMPENSATION_CODES' do
      it 'contains the expected codes' do
        expected = %w[010INITMORE8 010LCOMP 010LCOMPBDD 020CLMINC 020NEW 020NI 020SUPP 110INITLESS8 110LCOMP7]
        expect(BenefitsClaims::TitleGenerator::DISABILITY_COMPENSATION_CODES).to eq(expected)
      end

      it 'contains unique codes' do
        codes = BenefitsClaims::TitleGenerator::DISABILITY_COMPENSATION_CODES
        expect(codes.uniq.length).to eq(codes.length)
      end

      it 'contains only string values' do
        codes = BenefitsClaims::TitleGenerator::DISABILITY_COMPENSATION_CODES
        expect(codes.all? { |code| code.is_a?(String) }).to be true
      end
    end

    describe 'CLAIM_TYPE_SPECIAL_CASES' do
      it 'contains only the Death special case' do
        expect(BenefitsClaims::TitleGenerator::CLAIM_TYPE_SPECIAL_CASES.keys).to eq(['Death'])
      end

      it 'has proper Title struct for Death case' do
        death_title = BenefitsClaims::TitleGenerator::CLAIM_TYPE_SPECIAL_CASES['Death']
        expect(death_title.display_title).to eq('Claim for expenses related to death or burial')
        expect(death_title.claim_type_base).to eq('expenses related to death or burial claim')
      end
    end

    describe 'CLAIM_TYPE_CODE_MAPPING' do
      it 'includes all dependency codes' do
        mapping = BenefitsClaims::TitleGenerator::CLAIM_TYPE_CODE_MAPPING
        BenefitsClaims::TitleGenerator::DEPENDENCY_CODES.each do |code|
          expect(mapping).to have_key(code)
          expect(mapping[code].display_title).to eq('Request to add or remove a dependent')
        end
      end

      it 'includes all pension codes' do
        mapping = BenefitsClaims::TitleGenerator::CLAIM_TYPE_CODE_MAPPING
        all_pension_codes = BenefitsClaims::TitleGenerator::VETERANS_PENSION_CODES +
                            BenefitsClaims::TitleGenerator::SURVIVORS_PENSION_CODES +
                            BenefitsClaims::TitleGenerator::DIC_CODES

        all_pension_codes.each do |code|
          expect(mapping).to have_key(code)
        end
      end

      it 'includes all claimant substitution codes' do
        mapping = BenefitsClaims::TitleGenerator::CLAIM_TYPE_CODE_MAPPING
        BenefitsClaims::TitleGenerator::CLAIMANT_SUBSTITUTION_CODES.each do |code|
          expect(mapping).to have_key(code)
          expect(mapping[code].display_title).to eq('Request for substitution of claimant on record')
          expect(mapping[code].claim_type_base).to eq('request for substitution of claimant on record')
        end
      end

      it 'includes all disability compensation codes' do
        mapping = BenefitsClaims::TitleGenerator::CLAIM_TYPE_CODE_MAPPING
        BenefitsClaims::TitleGenerator::DISABILITY_COMPENSATION_CODES.each do |code|
          expect(mapping).to have_key(code)
          expect(mapping[code].display_title).to eq('Claim for disability compensation')
          expect(mapping[code].claim_type_base).to eq('disability compensation claim')
        end
      end
    end

    describe 'Title struct' do
      it 'creates Title struct with keyword arguments' do
        title = BenefitsClaims::TitleGenerator::Title.new(
          display_title: 'Test Title',
          claim_type_base: 'test base'
        )

        expect(title.display_title).to eq('Test Title')
        expect(title.claim_type_base).to eq('test base')
      end

      it 'converts Title to hash correctly' do
        title = BenefitsClaims::TitleGenerator::Title.new(
          display_title: 'Test Title',
          claim_type_base: 'test base'
        )

        expect(title.to_h).to eq({
                                   display_title: 'Test Title',
                                   claim_type_base: 'test base'
                                 })
      end
    end
  end
end
