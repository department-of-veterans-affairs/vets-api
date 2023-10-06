# frozen_string_literal: true

module EducationForm::Forms
  class VA0993 < Base
    def header_form_type
      'OPTOUT'
    end

    def applicant_name
      @applicant.claimantFullName
    end

    def applicant_ssn
      @applicant.claimantSocialSecurityNumber
    end
  end
end
