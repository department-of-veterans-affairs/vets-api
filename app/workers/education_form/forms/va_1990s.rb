# frozen_string_literal: true

module EducationForm::Forms
  class VA1990s < Base
    def header_form_type
      '1990S'
    end

    LEARNING_FORMAT = {
        'inPerson': 'In person',
        'online': 'Online',
        'onlineAndInPerson': 'Online and in person'
    }.freeze

    def location
      return '' if @applicant.providerName.blank?

      "#{@applicant.programCity}, #{@applicant.programState}"
    end

    def bank_routing_number
      if @applicant.bankAccount&.routingNumber.present?
        @applicant.bankAccount.routingNumber
      end
    end

    def bank_account_number
      if @applicant.bankAccount&.accountNumber.present?
        @applicant.bankAccount.accountNumber
      end
    end

    def bank_account_type
      if @applicant.bankAccount&.accountType.present?
        @applicant.bankAccount.accountType
      end
    end
  end
end
