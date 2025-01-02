# frozen_string_literal: true

require 'evss/disability_compensation_form/service'
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
    attribute :maximum_rating_percentage, Integer
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

  # internal form prefill
  # does not reach out to external services
  class Form526Prefill
    include Virtus.model

    attribute :started_form_version, String
    attribute :sync_modern_0781_flow, Boolean
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

    api_provider = ApiProviderFactory.call(
      type: ApiProviderFactory::FACTORIES[:rated_disabilities],
      provider: nil,
      options: {
        icn: user.icn.to_s,
        auth_headers: EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
      },
      current_user: user,
      feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_RATED_DISABILITIES_FOREGROUND
    )
    invoker = 'FormProfiles::VA526ez#initialize_rated_disabilities_information'
    response = api_provider.get_rated_disabilities(nil, nil, { invoker: })
    ClaimFastTracking::MaxRatingAnnotator.annotate_disabilities(response)

    # Remap response object to schema fields
    VA526ez::FormRatedDisabilities.new(
      rated_disabilities: response.rated_disabilities
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
      # any form that has a startedFormVersion (whether it is '2019' or '2022') will go through the Toxic Exposure flow
      # '2022' means the Toxic Exposure 1.0 flag.
      started_form_version: Flipper.enabled?(:disability_526_toxic_exposure, user) ? '2022' : nil,
      sync_modern_0781_flow: Flipper.enabled?(:disability_compensation_sync_modern_0781_flow, user)
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
    return {} unless user.authorize :evss, :access?

    contact_info = initialize_vets360_contact_info

    contact_info = VA526ez::FormContactInformation.new(contact_info)

    VA526ez::FormVeteranContactInformation.new(
      veteran: contact_info
    )
  end

  def initialize_payment_information
    return {} unless user.authorize(:ppiu, :access?) && user.authorize(:evss, :access?)

    provider = ApiProviderFactory.call(type: ApiProviderFactory::FACTORIES[:ppiu],
                                       current_user: user,
                                       feature_toggle: ApiProviderFactory::FEATURE_TOGGLE_PPIU_DIRECT_DEPOSIT)
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
    log_ppiu_error(e, provider)
    {}
  end

  def log_ppiu_error(e, provider)
    method_name = '#initialize_payment_information'
    error_message = "#{method_name} Failed to retrieve PPIU data from #{provider.class}: #{e.message}"
    Rails.logger.error(error_message)
  end

  def mask(number)
    number.gsub(/.(?=.{4})/, '*')
  end
end
