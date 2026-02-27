# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section04
  ##
  # Section IV
  # Build and merge the marital information structured data entries.
  def merge_marital_info
    pregnant_with_veteran, lived_with_veteran, discordant_separation, marriage_type = marital_info_data
    merge_veteran_separation_fields
    merge_claimant_remarriage_fields
    fields.merge!(y_n_pair(form['validMarriage'], 'AWARE_OF_MARRIAGE_VALIDITY_YES', 'AWARE_OF_MARRIAGE_VALIDITY_NO'))
    fields.merge!(y_n_pair(form['childWithVeteran'], 'CHILD_DURING_MARRIAGE_YES', 'CHILD_DURING_MARRIAGE_NO'))
    fields.merge!(y_n_pair(pregnant_with_veteran, 'EXPECTING_BIRTH_VET_CHILD_YES', 'EXPECTING_BIRTH_VET_CHILD_NO'))
    fields.merge!(y_n_pair(lived_with_veteran, 'LIVE_WITH_VET_TILL_DEATH_YES', 'LIVE_WITH_VET_TILL_DEATH_NO'))
    fields.merge!(y_n_pair(discordant_separation, 'MARITAL_DISCORD_SEPARATION_Y', 'MARITAL_DISCORD_SEPARATION_N'))
    fields.merge!(y_n_pair(marriage_type == 'ceremonial', 'CB_CL_MARR_1_TYPE_CEREMONIAL', 'CB_CL_MARR_1_TYPE_OTHER'))
    fields.merge!(
      {
        'VET_CLAIMANT_MARRIAGE_1_DATE' => format_date(form.dig('marriageDates', 'from')),
        'VET_CLAIMANT_MARRIAGE_1_DATE_ENDED' => format_date(form.dig('marriageDates', 'to')),
        'VET_CLAIMANT_MARRIAGE_1_PLACE' => form['placeOfMarriage'],
        'VET_CLAIMANT_MARRIAGE_1_PLACE_ENDED' => form['placeOfMarriageTermination'],
        'CL_MARR_1_TYPE_OTHEREXPLAIN' => form['marriageTypeExplanation'],
        'MARITAL_DISCORD_SEPARATION_EXP' => form['separationExplanation']
      }
    )
  end

  ##
  # Extract marital information from the form for structured data processing.
  #
  # @return [Array] An array containing the marital information values.
  def marital_info_data
    [
      form['pregnantWithVeteran'],
      form['livedContinuouslyWithVeteran'],
      form['separationDueToAssignedReasons'],
      form['marriageType']
    ]
  end

  ##
  # Build and merge the veteran separation fields
  def merge_veteran_separation_fields
    married_at_death = form['marriedToVeteranAtTimeOfDeath'] || false
    form['howMarriageEnded'] = married_at_death ? 'death' : form['howMarriageEnded']
    fields.merge!(y_n_pair(married_at_death, 'MARRIED_WHILE_VET_DEATH_Y', 'MARRIED_WHILE_VET_DEATH_N'))
    fields.merge!(
      {
        'CB_MARR_TO_VET_ENDED_DEATH' => form['howMarriageEnded'] == 'death',
        'CB_MARR_TO_VET_ENDED_DIVORCE' => form['howMarriageEnded'] == 'divorce',
        'CB_MARR_TO_VET_ENDED_OTHER' => form['howMarriageEnded'] == 'other'
      }
    )
    if form['howMarriageEnded'] == 'other'
      fields['MARR_TO_VET_ENDED_OTHEREXPLAIN'] = form['howMarriageEndedExplanation']
    end
  end

  ##
  # Build and merge the claimant remarriage fields
  def merge_claimant_remarriage_fields
    has_remarried = form['remarriedAfterVeteralDeath'] || false
    expand_and_merge_remarriage_end_cause(has_remarried, form['remarriageEndCause'])
    fields.merge!(y_n_pair(has_remarried, 'REMARRIED_AFTER_VET_DEATH_YES', 'REMARRIED_AFTER_VET_DEATH_NO'))
    fields.merge!(y_n_pair(form['claimantHasAdditionalMarriages'], 'ADDITIONAL_MARRIAGES_Y', 'ADDITIONAL_MARRIAGES_N'))
    fields.merge!(
      {
        'CLAIMANT_REMARRIAGE_1_DATE' => format_date(form.dig('remarriageDates', 'from')),
        'CLAIMANT_REMARRIAGE_1_DATE_ENDED' => format_date(form.dig('remarriageDates', 'to')),
        'REMARRIAGE_OTHER_EXPLANATION' => form['remarriageEndCauseExplanation']
      }
    )
  end

  ##
  # Build and merge the claimant remarriage end cause fields
  # @param has_remarried [Boolean] Indicates if the claimant has remarried
  # @param remarriage_end_cause [String] The cause of remarriage end, expected values:
  #   'death', 'divorce', 'didNotEnd', 'other'
  def expand_and_merge_remarriage_end_cause(has_remarried, remarriage_end_cause)
    if has_remarried && remarriage_end_cause
      fields.merge!(
        {
          'CB_REMARRIAGE_END_BY_DEATH' => remarriage_end_cause == 'death',
          'CB_REMARRIAGE_END_BY_DIVORCE' => remarriage_end_cause == 'divorce',
          'CB_MARRIAGE_DID_NOT_END' => remarriage_end_cause == 'didNotEnd',
          'CB_REMARRIAGE_END_BY_OTHER' => remarriage_end_cause == 'other'
        }
      )
    end
  end
end
