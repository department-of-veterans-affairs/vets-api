# frozen_string_literal: true

require 'evss/disability_compensation_form/service'
require 'evss/pciu_address/service'
require 'evss/ppiu/service'
require 'disability_compensation/factories/api_provider_factory'

module VA526ez
  class FormSpecialIssue
    include Virtus.model

    attribute :code, String
    attribute :name, String
  end

  class FormRatedDisability
    include Virtus.model

    attribute :name, String
    attribute :rated_disability_id, String
    attribute :rating_decision_id, String
    attribute :diagnostic_code, Integer
    attribute :decision_code, String
    attribute :decision_text, String
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

  class FormAddress
    include Virtus.model

    attribute :country
    attribute :city
    attribute :state
    attribute :zip_code
    attribute :address_line_1
    attribute :address_line_2
    attribute :address_line_3
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
  FORM_ID = '21-526EZ'
  attribute :rated_disabilities_information, VA526ez::FormRatedDisabilities
  attribute :veteran_contact_information, VA526ez::FormContactInformation
  attribute :payment_information, VA526ez::FormPaymentAccountInformation

  def prefill
    @rated_disabilities_information = initialize_rated_disabilities_information
    @veteran_contact_information = initialize_veteran_contact_information
    @payment_information = initialize_payment_information
    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/veteran-information'
    }
  end

  def initialize_rated_disabilities_information
    return {} unless user.authorize :evss, :access?

    settings = Settings.lighthouse.veteran_verification.form526
    service = ApiProviderFactory.rated_disabilities_service_provider(
      {
        auth_headers: EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h),
        icn: user.icn.to_s
      }
    )
    response = service.get_rated_disabilities(settings.access_token.client_id, settings.access_token.rsa_key)

    # Remap response object to schema fields
    VA526ez::FormRatedDisabilities.new(
      rated_disabilities: response.rated_disabilities
    )
  end

  private

  def initialize_vets360_contact_info
    return {} unless vet360_contact_info

    {
      mailing_address: convert_vets360_address(vet360_mailing_address),
      email_address: vet360_contact_info&.email&.email_address,
      primary_phone: [
        vet360_contact_info&.home_phone&.area_code,
        vet360_contact_info&.home_phone&.phone_number
      ].join
    }.compact
  end

  def initialize_veteran_contact_information
    return {} unless user.authorize :evss, :access?

    # fill in blank values with PCIU data
    return_val = initialize_vets360_contact_info.merge(
      mailing_address: get_common_address,
      email_address: extract_pciu_data(:pciu_email),
      primary_phone: pciu_us_phone
    ) { |_, old_val, new_val| old_val.presence || new_val }

    contact_info = VA526ez::FormContactInformation.new(return_val)

    VA526ez::FormVeteranContactInformation.new(
      veteran: contact_info
    )
  end

  def convert_vets360_address(address)
    return if address.blank?

    {
      address_line_1: address.address_line1,
      address_line_2: address.address_line2,
      address_line_3: address.address_line3,
      city: address.city,
      country: address.country_code_iso3,
      state: address.state_code || address.province,
      zip_code: address.zip_plus_four || address.international_postal_code
    }.compact
  end

  # Convert PCIU address to a Common address type
  def get_common_address
    service = EVSS::PCIUAddress::Service.new(user)
    response = service.get_address
    case response.address
    when EVSS::PCIUAddress::DomesticAddress
      prefill_domestic_address(response.address)
    when EVSS::PCIUAddress::InternationalAddress
      prefill_international_address(response.address)
    when EVSS::PCIUAddress::MilitaryAddress
      prefill_military_address(response.address)
    else
      {}
    end
  rescue
    {}
  end

  def prefill_domestic_address(address)
    {
      country: address&.country_name,
      city: address&.city,
      state: address&.state_code,
      zip_code: address&.zip_code,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end

  def prefill_international_address(address)
    {
      country: address&.country_name,
      city: address&.city,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end

  def prefill_military_address(address)
    {
      country: 'USA',
      city: address&.military_post_office_type_code,
      state: address&.military_state_code,
      zip_code: address&.zip_code,
      address_line_1: address&.address_one,
      address_line_2: address&.address_two,
      address_line_3: address&.address_three
    }.compact
  end

  def initialize_payment_information
    return {} unless user.authorize(:ppiu, :access?) && user.authorize(:evss, :access?)

    service = EVSS::PPIU::Service.new(user)
    response = service.get_payment_information
    raw_account = response.responses.first&.payment_account

    if raw_account
      VA526ez::FormPaymentAccountInformation.new(
        account_type: raw_account&.account_type&.capitalize,
        account_number: mask(raw_account&.account_number),
        routing_number: mask(raw_account&.financial_institution_routing_number),
        bank_name: raw_account&.financial_institution_name
      )
    else
      {}
    end
  rescue => e
    Rails.logger.error "Failed to retrieve PPIU data: #{e.message}"
    {}
  end

  def mask(number)
    number.gsub(/.(?=.{4})/, '*')
  end
end
