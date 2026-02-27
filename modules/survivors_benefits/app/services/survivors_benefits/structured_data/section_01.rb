# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section01
  include HasStructuredData
  ##
  # Section I
  # Build and merge the veteran-specific structured data entries.
  def merge_veterans_id_info
    merge_name_fields(form['veteranFullName'], 'VETERAN')
    fields.merge!(y_n_pair(form['vaClaimsHistory'], 'VETSPCHPAR_FILECLAIM_Y', 'VETSPCHPAR_FILECLAIM_N'))
    fields.merge!(y_n_pair(form['diedOnDuty'], 'VETDIED_ACTIVEDUTY_Y', 'VETDIED_ACTIVEDUTY_N'))
    fields.merge!(
      {
        'VETERAN_SSN' => form['veteranSocialSecurityNumber'],
        'VETERAN_DOB' => format_date(form['veteranDateOfBirth']),
        'VA_FILE_NUMBER' => form['vaFileNumber'],
        'VETERANS_SERVICE_NUMBER' => form['veteranServiceNumber'],
        'VETERAN_DATE_OF_DEATH' => format_date(form['veteranDateOfDeath'])
      }
    )
  end
end
