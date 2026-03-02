# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section08
  ##
  # Section VIII
  # Build and merge nursing home or increased survivors entitlement structured data entries.
  def build_section8
    fields.merge!(y_n_pair(form['claimantLivesInANursingHome'], 'CL_IN_NURSING_HOME_Y', 'CL_IN_NURSING_HOME_N'))
    fields.merge!(y_n_pair(form['claimingMonthlySpecialPension'], 'SPECIAL_ISSUE_YES', 'SPECIAL_ISSUE_NO'))
  end
end
