# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section05
  include HasStructuredData
  ##
  # Section V
  # Build the marital history structured data entries.
  def merge_marital_history
    vet_prev_marriages = form['veteranMarriages'] || []
    spouse_prev_marriages = form['spouseMarriages'] || []
    merge_previous_marriage_fields(vet_prev_marriages, 'VETERAN', form['veteranHasAdditionalMarriages'])
    merge_previous_marriage_fields(spouse_prev_marriages, 'CLAIMANT', form['spouseHasAdditionalMarriages'])
  end

  ##
  # Build and merge the previous marriage fields for either the veteran or claimant.
  #
  # @param marriages [Array<Hash>] An array of previous marriage data hashes
  # @param individual [String] The prefix for the field keys (e.g., "VETERAN", "CLAIMANT")
  # @param add_marr_field [String] The form field name that indicates if there are additional marriages
  #   (e.g., "veteranHasAdditionalMarriages")
  def merge_previous_marriage_fields(marriages, individual, add_marr_field)
    indv_s, indv_m, indv_l = individuals_permutations(individual) # s, m, l versions of individual for field naming
    additional_marriages_yes, additional_marriages_no = additional_marriages_boolean_fields(indv_s)
    fields.merge!(y_n_pair(add_marr_field, additional_marriages_yes, additional_marriages_no))

    marriages&.each_with_index do |marriage, index|
      marriage_num = index + 1
      merge_spouse_name_fields(marriage['spouseFullName'], indv_l, marriage_num)
      merge_previous_marriage_separation_type_fields(indv_s, marriage['reasonForSeparation'], marriage_num)
      fields.merge!(
          {
            "#{indv_m}_MARR#{marriage_num}_ENDED_OTHEREXPLAIN" => marriage['reasonForSeparationExplanation'],
            "#{indv_l}_MARRIAGE_#{marriage_num}_DATE" => format_date(marriage['dateOfMarriage']),
            "#{indv_l}_MARRIAGE_#{marriage_num}_DATE_ENDED" => format_date(marriage['dateOfSeparation']),
            "#{indv_l}_MARRIAGE_#{marriage_num}_PLACE" => marriage['locationOfMarriage'],
            "#{indv_l}_MARRIAGE_#{marriage_num}_PLACE_ENDED" => marriage['locationOfSeparation']
          }
        )
    end
  end

  ##
  # Get the individual permutations for field naming based on whether it's for the veteran or claimant.
  #
  # @param individual [String] "VETERAN" or "CLAIMANT"
  # @return [Array<String>] An array containing the short, medium, and long versions of the individual
  #   prefix for field naming
  def individuals_permutations(individual)
    if individual == 'VETERAN'
      %w[VET VET VETERAN]
    elsif individual == 'CLAIMANT'
      %w[CL CB_CL CLAIMANT]
    end
  end

  ##
  # Get the yes/no field names for additional marriages based on the individual.
  #
  # @param individual [String] "VETERAN" or "CLAIMANT"
  # @return [Array<String>] An array containing the yes and no field names for additional marriages
  def additional_marriages_boolean_fields(individual)
    ["#{individual}_ADDITIONAL_MARRIAGES_Y", "#{individual}_ADDITIONAL_MARRIAGES_N"]
  end

  ##
  # Build and merge the spouse name fields for a previous marriage.
  #
  # @param name [Hash] The spouse's full name data
  # @param individual [String] The prefix for the field keys (e.g., "VETERAN", "CLAIMANT")
  # @param marriage_num [Integer] The number of the marriage (e.g., 1 for the first previous marriage,
  #    2 for the second, etc.)
  def merge_spouse_name_fields(name, individual, marriage_num)
    spouse_name = build_name(name)
    fields.merge!(
      {
        "#{individual}_MARRIAGE_#{marriage_num}_TO" => spouse_name[:full],
        "#{individual}_MARRIAGE_#{marriage_num}_TO_FIRST_NAME" => spouse_name[:first],
        "#{individual}_MARRIAGE_#{marriage_num}_TO_MID_INT" => spouse_name[:middle_initial],
        "#{individual}_MARRIAGE_#{marriage_num}_TO_LAST_NAME" => spouse_name[:last]
      }
    )
  end

  ##
  # Build and merge the previous marriage separation type fields based on the reason for separation.
  #
  # @param individual [String] The prefix for the field keys (e.g., "VETERAN", "CLAIMANT")
  # @param reason [String] The reason for separation, expected values: "DEATH", "DIVORCE", "OTHER"
  # @param marriage_num [Integer] The number of the marriage (e.g., 1 for the first previous marriage,
  #    2 for the second, etc.)
  def merge_previous_marriage_separation_type_fields(individual, reason, marriage_num)
    fields.merge!(
      {
        "CB_#{individual}_MARR#{marriage_num}_ENDED_DEATH" => reason == 'DEATH',
        "CB_#{individual}_MARR#{marriage_num}_ENDED_DIVORCE" => reason == 'DIVORCE',
        "CB_#{individual}_MARR#{marriage_num}_ENDED_OTHER" => reason == 'OTHER'
      }
    )
  end
end
