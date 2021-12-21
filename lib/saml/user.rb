# frozen_string_literal: true

require 'saml/user_attributes/ssoe'
require 'sentry_logging'
require 'base64'

module SAML
  class User
    include SentryLogging

    UNKNOWN_AUTHN_CONTEXT = 'unknown'
    MHV_ORIGINAL_CSID = 'mhv'
    MHV_MAPPED_CSID = 'myhealthevet'
    IDME_CSID = 'idme'
    DSLOGON_CSID = 'dslogon'
    LOGINGOV_CSID = 'logingov'

    AUTHN_CONTEXTS = {
      LOA::IDME_LOA1_VETS => { loa_current: LOA::ONE, sign_in: { service_name: IDME_CSID } },
      LOA::IDME_LOA3_VETS => { loa_current: LOA::THREE, sign_in: { service_name: IDME_CSID } },
      LOA::IDME_LOA3 => { loa_current: LOA::THREE, sign_in: { service_name: IDME_CSID } },
      'multifactor' => { loa_current: nil, sign_in: { service_name: IDME_CSID } },
      'myhealthevet_multifactor' => { loa_current: nil, sign_in: { service_name: MHV_MAPPED_CSID } },
      'myhealthevet_loa3' => { loa_current: LOA::THREE, sign_in: { service_name: MHV_MAPPED_CSID } },
      'dslogon_multifactor' => { loa_current: nil, sign_in: { service_name: DSLOGON_CSID } },
      'dslogon_loa3' => { loa_current: LOA::THREE, sign_in: { service_name: DSLOGON_CSID } },
      'myhealthevet' => { loa_current: nil, sign_in: { service_name: MHV_MAPPED_CSID } },
      'dslogon' => { loa_current: nil, sign_in: { service_name: DSLOGON_CSID } },
      IAL::LOGIN_GOV_IAL1 => { loa_current: LOA::ONE, sign_in: { service_name: LOGINGOV_CSID } },
      IAL::LOGIN_GOV_IAL2 => { loa_current: LOA::THREE, sign_in: { service_name: LOGINGOV_CSID } }
    }.freeze

    LOGIN_TYPES = [MHV_MAPPED_CSID, IDME_CSID, DSLOGON_CSID, LOGINGOV_CSID].freeze

    attr_reader :saml_response, :saml_attributes, :user_attributes, :tracker_uuid

    delegate :to_hash, to: :user_attributes

    def initialize(saml_response)
      @saml_response = saml_response
      @saml_attributes = saml_response.attributes
      @tracker_uuid = saml_response.in_response_to

      Raven.extra_context(
        saml_attributes: saml_attributes&.to_h,
        saml_response: Base64.encode64(saml_response&.response || '')
      )

      @user_attributes = SAML::UserAttributes::SSOe.new(saml_attributes, authn_context, tracker_uuid)

      Raven.tags_context(
        sign_in_service_name: user_attributes.sign_in&.fetch(:service_name, nil),
        sign_in_account_type: user_attributes.sign_in&.fetch(:account_type, nil)
      )
    end

    def validate!
      @user_attributes.validate!
    end

    def changing_multifactor?
      return false if authn_context.nil?

      authn_context.include?('multifactor')
    end

    private

    def authn_context
      saml_response.authn_context_text
    rescue
      Raven.tags_context(controller_name: 'sessions', sign_in_method: 'not-signed-in:error')
      raise
    end
  end
end
