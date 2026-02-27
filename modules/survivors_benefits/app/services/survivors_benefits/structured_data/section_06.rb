# frozen_string_literal: true

module SurvivorsBenefits::StructuredData::Section06
  ##
  # Section VI
  # Build and mergethe children of the veteran structured data entries.
  def merge_children_of_veteran_info
    live_w_children = form['childrenLiveTogetherButNotWithSpouse']
    fields.merge!({ 'NUMBER_OF_DEP_CHILD' => form['veteranChildrenCount}'] })
    fields.merge!(y_n_pair(live_w_children, 'CHILD_DO_NOT_LIVE_WITH_CL_Y', 'CHILD_DO_NOT_LIVE_WITH_CL_N'))
    fields.merge!(merge_custodian_fields) unless live_w_children

    children = form['veteransChildren'] || []
    children&.each_with_index do |child, index|
      child_num = index + 1
      fields.merge!(build_child_relationship_fields(child['relationship'], child_num))
      fields.merge!(
        build_child(child, child_num)
      )
    end
  end

  ##
  # Build and merge the structured data fields for the custodian of the veteran's children.
  def merge_custodian_fields
    custodian_name = build_name(form['custodianFullName'])
    custodian_address = form['custodianAddress'] || {}
    fields.merge!(
      {
        'CUSTODIAN_CHILD1_NAME' => custodian_name[:full],
        'CUSTODIAN_CHILD1_FIRST_NAME' => custodian_name[:first],
        'CUSTODIAN_CHILD1_MID_INT' => custodian_name[:middle_initial],
        'CUSTODIAN_CHILD1_LAST_NAME' => custodian_name[:last],
        'CUSTODIAN_ADDRESS_LINE_1' => custodian_address['street'],
        'CUSTODIAN_ADDRESS_LINE_2' => custodian_address['street2'],
        'CUSTODIAN_ADDRESS_CITY' => custodian_address['city'],
        'CUSTODIAN_ADDRESS_STATE' => custodian_address['state'],
        'CUSTODIAN_ADDRESS_COUNTRY' => custodian_address['country'],
        'CUSTODIAN_ADDRESS_ZIP' => custodian_address['postalCode'][0..4],
        'CUSTODIAN_CHILD_NAME_ADDRESS' => [
          custodian_name[:full],
          build_address_block(custodian_address)
        ].compact.join(', ')
      }
    )
  end

  ##
  # Build and merge the structured data fields for a veteran/child relationship
  #
  # @param child [String] The veteran/child relationship type (e.g., "BIOLOGICAL", "ADOPTED", "STEPCHILD")
  # @param child_num [Integer] The number of the child (e.g., 1 for the first child, 2 for the second, etc.)
  def build_child_relationship_fields(relationship, child_num)
    fields.merge!(
      {
        "BIOLOGICAL_CHILD_#{child_num}" => relationship == 'BIOLOGICAL',
        "ADOPTED_CHILD_#{child_num}" => relationship == 'ADOPTED',
        "STEPCHILD_#{child_num}" => relationship == 'STEPCHILD'
      }
    )
  end

  ##
  # Build and merge the structured data fields for a veteran's child based on the child's information.
  #
  # @param child [Hash] The child's information from the form
  def build_child(child, child_num)
    child_name = build_name(child['childFullName'])
    fields.merge!(
      {
        "NAME_OF_CHILD_#{child_num}" => child_name[:full],
        "FIRST_NAME_OF_CHILD_#{child_num}" => child_name[:first],
        "MID_INT_OF_CHILD_#{child_num}" => child_name[:middle_initial],
        "LAST_NAME_OF_CHILD_#{child_num}" => child_name[:last],
        "DATE_OF_BIRTH_CHILD_#{child_num}" => format_date(child['childDateOfBirth']),
        "CHILD_#{child_num}_SSN" => child['childSocialSecurityNumber'],
        "PLACE_OF_BIRTH_CHILD_#{child_num}" => format_place(child['birthPlace']),
        "CHILD_#{child_num}_18_TO_23" => child['inSchool'],
        "CHILD_#{child_num}_DISABLED" => child['seriouslyDisabled'],
        "CHILD_#{child_num}_PREV_MARRIED" => child['hasBeenMarried'],
        "CB_CHILD#{child_num}_LIVE_WITH_OTHERS" => child['livesWith'],
        "AMNT_CONTRIBUTE_TO_CHILD_#{child_num}" => format_currency(child['childSupport'])
      }
    )
  end
end
