# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section03
  ##
  # Section III
  # Build the veteran service info structured data entries.
  #
  # @return [Hash]
  def build_section3
    merge_vet_aliases(form['veteranPreviousNames'])
    merge_service_branch_fields(form['serviceBranch'])
    fields.merge!(y_n_pair(form['nationalGuardActivated'], 'ACTIVATED_TO_FED_DUTY_YES', 'ACTIVATED_TO_FED_DUTY_NO'))
    fields.merge!(y_n_pair(form['pow'], 'POW_YES', 'POW_NO'))
    fields.merge!(
      {
        'DATE_ENTERED_TO_SERVICE' => format_date(form.dig('activeServiceDateRange', 'from')),
        'DATE_SEPARATED_FROM_SERVICE' => format_date(form.dig('activeServiceDateRange', 'to')),
        'PLACE_SEPARATED_FROM_SERVICE_1' => form['placeOfSeparation'],
        'DATE_OF_ACTIVATION' => format_date(form['nationalGuardActivationDate']),
        'NAME_ADDRESS_RESERVE_UNIT' => form['unitNameAndAddress'],
        'RESERVE_PHONE_NUMBER' => form['unitPhone'],
        'DATE_OF_CONFINEMENT_START' => form['pow'] ? format_date(form.dig('powDateRange', 'from')) : nil,
        'DATE_OF_CONFINEMENT_END' => form['pow'] ? format_date(form.dig('powDateRange', 'to')) : nil
      }
    )
  end

  ##
  # Build and merge the veteran alias fields
  #
  # @param aliases [Array<Hash>]
  def merge_vet_aliases(aliases = [])
    has_aliases = aliases&.length&.positive? || false
    fields.merge!(y_n_pair(has_aliases, 'VET_NAME_OTHER_Y', 'VET_NAME_OTHER_N'))
    n1 = aliases&.first || {}
    n2 = aliases&.second || {}
    fields.merge!(
      {
        'VET_NAME_OTHER_1' => [n1['first'], n1['middle'], n1['last'], n1['suffix']].compact.join(' ').presence,
        'VET_NAME_OTHER_2' => [n2['first'], n2['middle'], n2['last'], n2['suffix']].compact.join(' ').presence
      }
    )
  end

  ##
  # Build and merge the veteran service branch fields
  #
  # @param branch [String]
  def merge_service_branch_fields(branch)
    if branch
      fields.merge!(
        {
          'BRANCH_OF_SERVICE_ARMY' => branch == 'army',
          'BRANCH_OF_SERVICE_NAVY' => branch == 'navy',
          'BRANCH_OF_SERVICE_AIR-FORCE' => branch == 'airForce',
          'BRANCH_OF_SERVICE_MARINE' => branch == 'marineCorps',
          'BRANCH_OF_SERVICE_COAST-GUARD' => branch == 'coastGuard',
          'BRANCH_OF_SERVICE_SPACE' => branch == 'spaceForce',
          'BRANCH_OF_SERVICE_NOAA' => branch == 'usphs',
          'BRANCH_OF_SERVICE_USPHS' => branch == 'noaa'
        }
      )
    end
  end
end
