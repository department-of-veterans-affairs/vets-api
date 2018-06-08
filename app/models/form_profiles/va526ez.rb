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
    attribute :email_address, String
  end

  class FormVeteranContactInformation
    include Virtus.model

    attribute :veteran, FormContactInformation
  end
end

class FormProfiles::VA526ez < FormProfile
  attribute :rated_disabilities_information, VA526ez::FormRatedDisabilities
  attribute :veteran_contact_information, VA526ez::FormContactInformation

  def prefill(user)
    @rated_disabilities_information = initialize_rated_disabilities_information(user)
    @veteran_contact_information = initialize_veteran_contact_information(user)
    super(user)
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

    contact_info = VA526ez::FormContactInformation.new(
      mailing_address: get_pciu_address(user),
      email_address: pciu_email,
      primary_phone: get_us_phone(pciu_primary_phone)
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
  rescue StandardError
    {}
  end

  def get_pciu_address(user)
    service = EVSS::PCIUAddress::Service.new(user)
    response = service.get_address
    case response.address
    when EVSS::PCIUAddress::DomesticAddress
      prefill_pciu_domestic_address(response.address)
    when EVSS::PCIUAddress::InternationalAddress
      prefill_pciu_international_address(response.address)
    when EVSS::PCIUAddress::MilitaryAddress
      prefill_pciu_military_address(response.address)
    else
      {}
    end
  rescue StandardError
    {}
  end

  def prefill_pciu_domestic_address(address)
    {
      type: address&.type,
      country: address&.country_name,
      city: address&.city,
      state: address&.state_code,
      zip_code: address&.zip_code,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end

  def prefill_pciu_international_address(address)
    {
      type: address&.type,
      country: address&.country_name,
      city: address&.city,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end

  def prefill_pciu_military_address(address)
    {
      type: address&.type,
      military_post_office_type_code: address&.military_post_office_type_code,
      military_state_code: address&.military_state_code,
      zip_code: address&.zip_code,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end
end
