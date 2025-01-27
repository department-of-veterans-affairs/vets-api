# frozen_string_literal: true

module EducationForm::Forms
  class VA1990s < Base
    def header_form_type
      'V1990S'
    end

    LEARNING_FORMAT = {
      inPerson: 'In person',
      online: 'Online',
      onlineAndInPerson: 'Online and in person'
    }.freeze

    def location
      return '' if @applicant.providerName.blank?

      "#{@applicant.programCity}, #{@applicant.programState}"
    end

    def bank_routing_number
      @applicant.bankAccount.routingNumber if @applicant.bankAccount&.routingNumber.present?
    end

    def bank_account_number
      @applicant.bankAccount.accountNumber if @applicant.bankAccount&.accountNumber.present?
    end

    def bank_account_type
      @applicant.bankAccount.accountType if @applicant.bankAccount&.accountType.present?
    end

    def school_name
      @applicant.providerName
    end
  end
end
