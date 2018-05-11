# frozen_string_literal: true

module VA526ez
  class FormSpecialIssue
    include Virtus.model

    attribute :code, String
    attribute :name, String
  end

  class FormRatedDisability
    include Virtus.model

    attribute :name, String
    attribute :special_issues, Array[FormSpecialIssue]
    attribute :rated_disability_id, String
    attribute :rating_decision_id, String
    attribute :diagnostic_code, Integer
    attribute :rating_percentage, Integer
  end

  class FormRatedDisabilities
    include Virtus.model

    attribute :rated_disabilities, Array[FormRatedDisability]
  end

  class FormPaymentAccountInformation
    include Virtus.model

    attribute :account_type, String
    attribute :account_number, String
    attribute :routing_number, String
    attribute :bank_name, String
  end

  class FormPaymentInformation
    include Virtus.model

    attribute :payment_account, FormPaymentAccountInformation
  end

  class FormAddress
    include Virtus.model

    attribute :type
    attribute :country
    attribute :city
    attribute :state
    attribute :zip_code
    attribute :address_line_1
    attribute :address_line_2
    attribute :address_line_3
    attribute :military_post_office_type_code
    attribute :military_state_code
  end

  class FormContactInformation
    include Virtus.model

    attribute :mailing_address, FormAddress
    attribute :primary_phone, String
    attribute :secondary_phone, String
    attribute :email_address, String
  end

  class FormVeteranContactInformation
    include Virtus.model

    attribute :veteran, FormContactInformation
  end
end

class FormProfiles::VA526ez < FormProfile
  attribute :rated_disabilities_information, VA526ez::FormRatedDisabilities
  attribute :payment_information, VA526ez::FormPaymentInformation
  attribute :veteran_contact_information, VA526ez::FormContactInformation

  def prefill(user)
    @rated_disabilities_information = initialize_rated_disabilities_information(user)
    @payment_information = initialize_payment_information(user)
    @veteran_contact_information = initialize_veteran_contact_information(user)
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  private

  def initialize_veteran_contact_information(user)
    return {} unless user.authorize :evss, :access?

    pciu_email = extract_pciu_data(user, :pciu_email)
    pciu_primary_phone = extract_pciu_data(user, :pciu_primary_phone)
    pciu_alternate_phone = extract_pciu_data(user, :pciu_alternate_phone)

    contact_info = VA526ez::FormContactInformation.new(
      mailing_address: get_pciu_address(user),
      email_address: pciu_email,
      primary_phone: get_us_phone(pciu_primary_phone),
      secondary_phone: get_us_phone(pciu_alternate_phone)
    )

    VA526ez::FormVeteranContactInformation.new(
      veteran: contact_info
    )
  end

  def initialize_rated_disabilities_information(user)
    return {} unless user.authorize :evss, :access?

    service = EVSS::DisabilityCompensationForm::Service.new(user)
    response = service.get_rated_disabilities

    # Remap response object to schema fields
    VA526ez::FormRatedDisabilities.new(
      rated_disabilities: response.rated_disabilities
    )
  end

  def initialize_payment_information(user)
    return {} unless user.authorize :evss, :access?

    service = EVSS::PPIU::Service.new(user)
    response = service.get_payment_information
    raw_account = response.responses.first&.payment_account

    if raw_account
      account = VA526ez::FormPaymentAccountInformation.new(
        account_type: raw_account&.account_type&.upcase,
        account_number: raw_account&.account_number,
        routing_number: raw_account&.financial_institution_routing_number,
        bank_name: raw_account&.financial_institution_name
      )

      VA526ez::FormPaymentInformation.new(
        payment_account: account
      )
    else
      {}
    end
  end

  def get_pciu_address(user)
    service = EVSS::PCIUAddress::Service.new(user)
    response = service.get_address
    case response.address
    when EVSS::PCIUAddress::DomesticAddress
      prefill_pciu_domestic_address(response)
    when EVSS::PCIUAddress::InternationalAddress
      prefill_pciu_international_address(response)
    when EVSS::PCIUAddress::MilitaryAddress
      prefill_pciu_military_address(responsee)
    else
      {}
    end
  end

  def prefill_pciu_domestic_address(response)
    {
      type: response.address&.type,
      country: response.address&.country_name,
      city: response.address&.city,
      state: response.address&.state_code,
      zip_code: response&.address&.zip_code,
      address_line_1: response.address&.address_one,
      address_line_2: response.address&.address_two,
      address_line_3: response.address&.address_three
    }.compact
  end

  def prefill_pciu_international_address(response)
    {
      type: response.address&.type,
      country: response.address&.country_name,
      city: response.address&.city,
      address_line_1: response.address&.address_one,
      address_line_2: response.address&.address_two,
      address_line_3: response.address&.address_three
    }.compact
  end

  def prefill_pciu_military_address(response)
    {
      type: response.address&.type,
      military_post_office_type_code: response.address&.military_post_office_type_code,
      military_state_code: response.address&.military_state_code,
      zip_code: response.address&.zip_code,
      address_line_1: response.address&.address_one,
      address_line_2: response.address&.address_two,
      address_line_3: response.address&.address_three
    }.compact
  end
end
