# frozen_string_literal: true

module BGSDependents
  class Child < Base
    attribute :ssn, String
    attribute :first, String
    attribute :middle, String
    attribute :last, String
    attribute :suffix, String
    attribute :ever_married_ind, String
    attribute :place_of_birth_city, String
    attribute :place_of_birth_state, String
    attribute :reason_marriage_ended, String
    attribute :family_relationship_type, String

    CHILD_STATUS = {
      'step_child' => 'Stepchild',
      'biological' => 'Biological',
      'adopted' => 'Adopted Child',
      'disabled' => 'Other',
      'child_under18' => 'Other',
      'child_over18_in_school' => 'Other'
    }.freeze

    def initialize(child_info)
      @child_info = child_info

      self.attributes = child_attributes
    end

    def format_info
      self.attributes.with_indifferent_access
    end

    def address(dependents_application)
      dependent_address(
        dependents_application,
        @child_info.dig('does_child_live_with_you'),
        @child_info.dig('child_address_info', 'address')
      )
    end

    private

    def child_attributes
      {
        ssn: @child_info['ssn'],
        family_relationship_type: child_status,
        place_of_birth_state: @child_info.dig('place_of_birth', 'state'),
        place_of_birth_city: @child_info.dig('place_of_birth', 'city'),
        reason_marriage_ended: @child_info.dig('previous_marriage_details', 'reason_marriage_ended'),
        ever_married_ind: marriage_indicator
      }.merge(@child_info['full_name'])
    end

    def child_status
      CHILD_STATUS[@child_info.dig('child_status')&.key(true)]
    end

    def marriage_indicator
      @child_info.dig('previously_married') == 'Yes' ? 'Y' : 'N'
    end
  end
end
