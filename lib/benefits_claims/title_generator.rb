# frozen_string_literal: true

module BenefitsClaims
  class TitleGenerator
    # Title configuration for specific claim type codes
    Title = Struct.new(:display_title, :claim_type_base, keyword_init: true)

    # Dependency claims (47 codes from addOrRemoveDependentClaimTypeCodes)
    DEPENDENCY_TITLE = Title.new(
      display_title: 'Request to add or remove a dependent',
      claim_type_base: 'request to add or remove a dependent'
    ).freeze

    # Special case transformations
    CLAIM_TYPE_SPECIAL_CASES = {
      'Death' => Title.new(
        display_title: 'Claim for expenses related to death or burial',
        claim_type_base: 'expenses related to death or burial claim'
      )
    }.freeze

    DEPENDENCY_CODES = %w[
      130DPNDCYAUT 130DPNAUTREJ 130SCHATTAUT 130SCHAUTREJ 130ADOD2D
      130ADSD2D 130DAD2D 130DARD2D 130PDARD2D 130PSARD2D 130SAD2D
      130SARD2D 130DPNDCY 130DCY674 130DCY686 130DPV0538 130DRASDP
      130DPNEBNADJ 130DPEBNAJRE 130SCHATTEBN 130PDA 130PDAE 130PSA
      130PSAE 130DPNPMCAUT 130DPMCAUREJ 130SCPMAUREJ 130DV0538PMC
      130DPNDCYPMC 130DCY674PMC 130DCY686PMC 130DRASDPMC 130PDAPMC
      130PDAEPMC 130PSAPMC 130PSAEPMC 130SD2DPMC 130AD2DPMC 130DD2DPMC
      130D2DPMC 130ARD2DPMC 130ADOD2DPMC 130ADSD2DPMC 130DAD2DPMC
      130DARD2DPMC 130PDARD2DPM 130PSARD2DPM 130SARD2DPMC
    ].freeze

    # Pension subcategory mappings
    VETERANS_PENSION_CODES = %w[180AILP 180ORGPENPMC 180ORGPEN].freeze
    SURVIVORS_PENSION_CODES = %w[190ORGDPN 190ORGDPNPMC 190AID 140ISD 687NRPMC].freeze
    DIC_CODES = %w[290DICEDPMC 020SMDICPMC 020IRDICPMC].freeze

    GENERIC_PENSION_CODES = %w[
      150ELECPMC 150INCNWPMC 150INCPMC 120INCPMC 150NWTHPMC
      120SUPHCDPMC 120ILCP7PMC 120SMPPMC 150MERPMC 120ASMP
      120ARP 150AIA 600APCDP 600PCDPPM 696MROCPMC
    ].freeze

    # Build comprehensive code mapping
    CLAIM_TYPE_CODE_MAPPING = {}.tap do |mapping|
      # Add dependency codes
      DEPENDENCY_CODES.each { |code| mapping[code] = DEPENDENCY_TITLE }

      # Add veterans pension codes
      VETERANS_PENSION_CODES.each do |code|
        mapping[code] = Title.new(
          display_title: 'Claim for Veterans Pension',
          claim_type_base: 'veterans pension claim'
        )
      end

      # Add survivors pension codes
      SURVIVORS_PENSION_CODES.each do |code|
        mapping[code] = Title.new(
          display_title: 'Claim for Survivors Pension',
          claim_type_base: 'survivors pension claim'
        )
      end

      # Add DIC codes
      DIC_CODES.each do |code|
        mapping[code] = Title.new(
          display_title: 'Claim for Dependency and Indemnity Compensation',
          claim_type_base: 'dependency and indemnity compensation claim'
        )
      end

      # Add generic pension codes (remaining from pensionClaimTypeCodes)
      GENERIC_PENSION_CODES.each do |code|
        mapping[code] = Title.new(
          display_title: 'Claim for pension',
          claim_type_base: 'pension claim'
        )
      end

      # Add null claimType cases
      mapping['290DV'] = Title.new(
        display_title: 'Debt Validation',
        claim_type_base: 'debt validation'
      )
      mapping['290DVPMC'] = Title.new(
        display_title: 'PMC - Debt Validation',
        claim_type_base: 'debt validation'
      )
      mapping['130ISDDI'] = Title.new(
        display_title: 'In Service Death Dependency',
        claim_type_base: 'in service death dependency'
      )
      mapping['330DVRPMC'] = Title.new(
        display_title: 'Dependency Verification',
        claim_type_base: 'dependency verification'
      )
    end.freeze

    class << self
      def generate_titles(claim_type, claim_type_code)
        # trim whitespace on both sides
        claim_type = claim_type&.strip
        claim_type_code = claim_type_code&.strip

        # Priority 1: Check for specific claim type code override
        if claim_type_code && (title = CLAIM_TYPE_CODE_MAPPING[claim_type_code])
          return title.to_h
        end

        # Priority 2: Check for special case transformations
        if claim_type && (title = CLAIM_TYPE_SPECIAL_CASES[claim_type])
          return title.to_h
        end

        # Priority 3: Generate default title for any claimType
        if claim_type.present?
          claim_type_lower = claim_type.downcase
          return {
            display_title: "Claim for #{claim_type_lower}",
            claim_type_base: "#{claim_type_lower} claim"
          }
        end

        # Priority 4: Return nil for missing data (triggers frontend fallback)
        { display_title: nil, claim_type_base: nil }
      end

      def update_claim_title(claim)
        return claim if claim.blank?

        claim_type = claim.dig('attributes', 'claimType')
        claim_type_code = claim.dig('attributes', 'claimTypeCode')

        titles = generate_titles(claim_type, claim_type_code)

        claim['attributes']['displayTitle'] = titles[:display_title]
        claim['attributes']['claimTypeBase'] = titles[:claim_type_base]
      rescue => e
        Rails.logger.error(e.message, {
                             error_class: self.class.to_s,
                             backtrace: e.backtrace&.first(3)
                           })
        claim
      end
    end
  end
end
