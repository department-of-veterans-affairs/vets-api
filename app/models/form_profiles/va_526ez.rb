# frozen_string_literal: true

require 'evss/disability_compensation_form/service'
require 'disability_compensation/factories/api_provider_factory'
require 'vets/model'

module VA526ez
  class FormSpecialIssue
    include Vets::Model

    attribute :code, String
    attribute :name, String
  end

  class FormRatedDisability
    include Vets::Model

    attribute :name, String
    attribute :rated_disability_id, String
    attribute :rating_decision_id, String
    attribute :diagnostic_code, Integer
    attribute :decision_code, String
    attribute :decision_text, String
    attribute :rating_percentage, Integer
    attribute :maximum_rating_percentage, Integer
  end

  class FormRatedDisabilities
    include Vets::Model

    attribute :rated_disabilities, FormRatedDisability, array: true
  end

  class FormPaymentAccountInformation
    include Vets::Model

    attribute :account_type, String
    attribute :account_number, String
    attribute :routing_number, String
    attribute :bank_name, String
  end

  class FormAddress
    include Vets::Model

    attribute :country, String
    attribute :city, String
    attribute :state, String
    attribute :zip_code, String
    attribute :address_line_1, String
    attribute :address_line_2, String
    attribute :address_line_3, String
  end

  class FormContactInformation
    include Vets::Model

    attribute :mailing_address, FormAddress
    attribute :primary_phone, String
    attribute :email_address, String
  end

  class FormVeteranContactInformation
    include Vets::Model

    attribute :veteran, FormContactInformation
  end

  # internal form prefill
  # does not reach out to external services
  class Form526Prefill
    include Vets::Model

    attribute :started_form_version, String
    attribute :sync_modern_0781_flow, Bool
    attribute :disability_comp_new_conditions_workflow, Bool
  end
end

class FormProfiles::VA526ez < FormProfile
  FORM_ID = '21-526EZ'
  attribute :rated_disabilities_information, VA526ez::FormRatedDisabilities
  attribute :veteran_contact_information, VA526ez::FormContactInformation
  attribute :payment_information, VA526ez::FormPaymentAccountInformation
  attribute :prefill_526, VA526ez::Form526Prefill

  def prefill
    @prefill_526 = initialize_form526_prefill

    begin
      @rated_disabilities_information = initialize_rated_disabilities_information
    rescue => e
      Rails.logger.error("Form526 Prefill for rated disabilities failed. #{e.message}")
    end

    begin
      @veteran_contact_information = initialize_veteran_contact_information
    rescue => e
      Rails.logger.error("Form526 Prefill for veteran contact information failed. #{e.message}")
    end

    begin
      @payment_information = initialize_payment_information
    rescue => e
      Rails.logger.error("Form526 Prefill for payment information failed. #{e.message}")
    end

    prefill_base_class_methods

    mappings = self.class.mappings_for_form(form_id)
    form_data = generate_prefill(mappings)
    { form_data:, metadata: }
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
    return {} unless user.authorize :lighthouse, :access_vet_status?

    api_provider = ApiProviderFactory.call(
      type: ApiProviderFactory::FACTORIES[:rated_disabilities],
      provider: :lighthouse,
      options: {
        icn: user.icn.to_s,
        auth_headers: EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
      },
      current_user: user,
      feature_toggle: nil
    )
    invoker = 'FormProfiles::VA526ez#initialize_rated_disabilities_information'
    response = api_provider.get_rated_disabilities(nil, nil, { invoker: })
    ClaimFastTracking::MaxRatingAnnotator.annotate_disabilities(response)

    # Remap response object to schema fields
    VA526ez::FormRatedDisabilities.new(
      rated_disabilities: response.rated_disabilities.map(&:attribute_values)
    )
  end

  private

  def prefill_base_class_methods
    begin
      @identity_information = initialize_identity_information
    rescue => e
      Rails.logger.error("Form526 Prefill for identity information failed. #{e.message}")
    end

    begin
      @contact_information = initialize_contact_information
    rescue => e
      Rails.logger.error("Form526 Prefill for contact information failed. #{e.message}")
    end

    begin
      @military_information = initialize_military_information
    rescue => e
      Rails.logger.error("Form526 Prefill for military information failed. #{e.message}")
    end
  end

  def initialize_form526_prefill
    VA526ez::Form526Prefill.new(
      started_form_version: '2022',
      sync_modern_0781_flow: Flipper.enabled?(:disability_compensation_sync_modern_0781_flow, user),
      disability_comp_new_conditions_workflow: Flipper.enabled?(:disability_compensation_new_conditions_workflow, user)
    )
  end

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
    return {} unless user.authorize :va_profile, :access_to_v2?

    contact_info = initialize_vets360_contact_info
    contact_info = VA526ez::FormContactInformation.new(contact_info)

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
    return {} unless user.authorize(:lighthouse, :direct_deposit_access?) && user.authorize(:evss, :access?)

    provider = ApiProviderFactory.call(type: ApiProviderFactory::FACTORIES[:ppiu],
                                       provider: ApiProviderFactory::API_PROVIDER[:lighthouse],
                                       current_user: user,
                                       feature_toggle: nil)
    response = provider.get_payment_information
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
    lighthouse_direct_deposit_error(e, provider)
    {}
  end

  def lighthouse_direct_deposit_error(e, provider)
    method_name = '#initialize_payment_information'
    error_message = "#{method_name} Failed to retrieve DirectDeposit data from #{provider.class}: #{e.message}"
    Rails.logger.error(error_message)
  end

  def mask(number)
    return nil if number.nil?

    number.gsub(/.(?=.{4})/, '*')
  end
end
