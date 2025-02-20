# frozen_string_literal: true

module BGSDependents
  class Child < Base
    # The Child class represents a veteran's dependent/child including name, address, and birth info
    #
    # @!attribute ssn
    #   @return [String] the person's social security number
    # @!attribute first
    #   @return [String] the person's first name
    # @!attribute middle
    #   @return [String] the person's middle name
    # @!attribute last
    #   @return [String] the person's last name
    # @!attribute suffix
    #   @return [String] the person's name suffix
    # @!attribute ever_married_ind
    #   @return [String] Y/N indicates whether the person has ever been married
    # @!attribute place_of_birth_city
    #   @return [String] city where child was born
    # @!attribute place_of_birth_state
    #   @return [String] state where child was born
    # @!attribute reason_marriage_ended
    #   @return [String] reason child marriage ended
    # @!attribute family_relationship_type
    #   @return [String] family relationship type: Biological/Stepchild/Adopted Child/Other
    # @!attribute child_income
    #   @return [String] did this child have income in the last 365 days
    #
    attribute :ssn, String
    attribute :first, String
    attribute :middle, String
    attribute :last, String
    attribute :suffix, String
    attribute :birth_date, String
    attribute :ever_married_ind, String
    attribute :place_of_birth_city, String
    attribute :place_of_birth_state, String
    attribute :place_of_birth_country, String
    attribute :reason_marriage_ended, String
    attribute :family_relationship_type, String
    attribute :child_income, String
    attribute :not_self_sufficient, String

    CHILD_STATUS = {
      'stepchild' => 'Stepchild',
      'biological' => 'Biological',
      'adopted' => 'Adopted Child',
      'disabled' => 'Other',
      'child_under18' => 'Other',
      'child_over18_in_school' => 'Other'
    }.freeze

    # These are required fields in BGS
    validates :first, presence: true
    validates :last, presence: true

    def initialize(child_info)
      @child_info = child_info
      @is_v2 = Flipper.enabled?(:va_dependents_v2)
      self.attributes = child_attributes
    end

    # Sets a hash with child attributes
    #
    # @return [Hash] child attributes including name, address and birth info
    #
    def format_info
      attributes.with_indifferent_access
    end

    # Sets a hash with address information based on the submitted form information
    #
    # @param dependents_application [Hash] the submitted form information
    # @return [Hash] child address
    #
    def address(dependents_application)
      dependent_address(
        dependents_application:,
        lives_with_vet: @child_info['does_child_live_with_you'],
        alt_address: @is_v2 ? @child_info.dig('address') : @child_info.dig('child_address_info', 'address')
      )
    end

    private

    def child_attributes
      place_of_birth = @is_v2 ? @child_info.dig('birth_location') : @child_info.dig('place_of_birth')
      {
        ssn: @child_info['ssn'],
        birth_date: @child_info['birth_date'],
        family_relationship_type: child_status,
        place_of_birth_country: @is_v2 ? place_of_birth.dig('location', 'country') : place_of_birth.dig('country'),
        place_of_birth_state: @is_v2 ? place_of_birth.dig('location', 'state') : place_of_birth.dig('state'),
        place_of_birth_city: @is_v2 ? place_of_birth.dig('location', 'city') : place_of_birth.dig('city'),
        reason_marriage_ended: @is_v2 ? @child_info.dig('marriage_end_reason') : @child_info.dig('previous_marriage_details', 'reason_marriage_ended'),
        ever_married_ind: marriage_indicator,
        child_income: formatted_boolean(@is_v2 ? @child_info['income_in_last_year'] : @child_info['child_income']),
        not_self_sufficient: formatted_boolean(@child_info['not_self_sufficient'])
      }.merge(@child_info['full_name'])
    end

    def child_status
      if @is_v2
        CHILD_STATUS[@child_info['relationship_to_child']&.key(true)]
      else
        CHILD_STATUS[@child_info['child_status']&.key(true)]
      end
    end

    def marriage_indicator
      if @is_v2
        @child_info['has_child_ever_been_married'] ? 'Y' : 'N'
      else
        @child_info['previously_married'] == 'Yes' ? 'Y' : 'N'
      end
    end
  end
end
