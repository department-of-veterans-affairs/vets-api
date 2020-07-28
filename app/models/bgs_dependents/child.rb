# frozen_string_literal: true

module BGSDependents
  class Child < Base
    CHILD_STATUS = {
      'child_under18' => 'Other',
      'step_child' => 'Stepchild',
      'biological' => 'Biological',
      'adopted' => 'Adopted Child',
      'disabled' => 'Other',
      'child_over18_in_school' => 'Other'
    }.freeze

    def initialize(child_info)
      @child_info = child_info
    end

    def format_info
      {
        'ssn': @child_info['ssn'],
        'family_relationship_type': CHILD_STATUS[@child_info['child_status'].key(true)],
        'place_of_birth_state': @child_info.dig('place_of_birth', 'state'),
        'place_of_birth_city': @child_info.dig('place_of_birth', 'city'),
        'reason_marriage_ended': @child_info.dig('previous_marriage_details', 'reason_marriage_ended'),
        'ever_married_ind': @child_info['previously_married'] == 'Yes' ? 'Y' : 'N'
      }.merge(@child_info['full_name']).with_indifferent_access
    end

    def address(dependents_application)
      dependent_address(
        dependents_application,
        @child_info['does_child_live_with_you'],
        @child_info.dig('child_address_info', 'address')
      )
    end
  end
end
