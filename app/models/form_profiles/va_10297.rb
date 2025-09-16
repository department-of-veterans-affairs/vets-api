# frozen_string_literal: true

require 'vets/model'

module VA10297
  FORM_ID = '22-10297'

  class FormPaymentAccountInformation
    include Vets::Model

    attribute :account_type, String
    attribute :account_number, String
    attribute :routing_number, String
    attribute :bank_name, String
  end
end

class FormProfiles::VA10297 < FormProfile
  attribute :payment_information, VA10297::FormPaymentAccountInformation

  def prefill
    @payment_information = initialize_payment_information
    result = super
    result[:form_data]['applicantFullName'].delete('suffix') # no name suffix needed in this schema

    result
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/applicant/information'
    }
  end

  private

  def initialize_payment_information
    return {} unless user.authorize(:lighthouse, :direct_deposit_access?) && user.authorize(:evss, :access?)

    provider = ApiProviderFactory.call(type: ApiProviderFactory::FACTORIES[:ppiu],
                                       provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
                                       current_user: user,
                                       feature_toggle: nil)
    response = provider.get_payment_information
    raw_account = response.responses.first&.payment_account

    if raw_account
      VA10297::FormPaymentAccountInformation.new(
        account_type: raw_account&.account_type&.capitalize,
        account_number: raw_account&.account_number,
        routing_number: raw_account&.financial_institution_routing_number,
        bank_name: raw_account&.financial_institution_name
      )
    else
      {}
    end
  rescue => e
    Rails.logger.error "FormProfiles::VA10297 Failed to retrieve Payment Information data: #{e.message}"
    {}
  end
end
