# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section07
  ##
  # Section VII
  # Build the D.I.C. structured data entries.
  #
  def build_section7
    merge_dic_type_fields(form['benefit'])
    treatments = form['treatments'] || []
    treatments&.each_with_index do |treatment, index|
      center_num = index + 1
      fields.merge!(
        {
          "NAME_LOC_MED_CENTER_#{center_num}" => treatment['facility'],
          "DATE_OF_TREATMENT_START#{center_num}" => format_date(treatment['startDate']),
          "DATE_OF_TREATMENT_END#{center_num}" => format_date(treatment['endDate'])
        }
      )
    end
  end

  ##
  # Build the structured data fields for the D.I.C. benefit type.
  #
  # @param benefit [String] The type of D.I.C. benefit (e.g., "DIC", "1151DIC", "pactActDIC")
  def merge_dic_type_fields(benefit)
    fields.merge!(
      {
        'BENEFIT_DIC' => benefit == 'DIC',
        'BENEFIT_DIC38' => benefit == '1151DIC',
        'CLAIM_TYPE_DIC_PACTACT' => benefit == 'pactActDIC'
      }
    )
  end
end
