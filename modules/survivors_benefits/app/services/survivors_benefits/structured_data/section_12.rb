# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section12
  ##
  # Section XII
  # Build and merge claim certification structured data entries.
  def build_section12
    fields.merge!(
      {
        'CB_FURTHER_EVD_CLAIM_SUPPORT' => false,
        'CLAIM_TYPE_FULLY_DEVELOPED_CHK' => true,
        'CLAIMANT_SIGNATURE_X' => form['claimantSignatureX'],
        'CLAIMANT_SIGNATURE' => form['claimantSignature'],
        'DATE_OF_CLAIMANT_SIGNATURE' => format_date(form['dateSigned'])
      }
    )
  end
end
