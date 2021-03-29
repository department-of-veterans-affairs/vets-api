# frozen_string_literal: true

module EducationForm::Forms
  class VA1990s < Base
    def header_form_type
      '1990s'
    end

    LEARNING_FORMAT = {
      'inPerson': 'In person',
      'online': 'Online',
      'onlineAndInPerson': 'Online and in person',
    }.freeze
    
    def applicant_ssn
      @applicant.veteranSocialSecurityNumber
    end

    def applicant_name
      @applicant.veteranFullName
    end

    def location
      return '' if @applicant.providerName.blank?

      "#{@applicant.programCity}, #{@applicant.programState}"
    end
    
    def full_address_with_street3(address, indent: false)
      return '' if address.nil?

      seperator = indent ? "\n        " : "\n"
      [
        address.street,
        address.street2,
        address.street3,
        [address.city, address.state, address.postalCode].compact.join(', '),
        address.country
      ].compact.join(seperator).upcase
    end

  end
end
