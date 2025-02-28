# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/lighthouse_rated_disabilities_provider'
require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'
require 'disability_compensation/providers/intent_to_file/lighthouse_intent_to_file_provider'
require 'disability_compensation/providers/intent_to_file/intent_to_file_provider'
require 'disability_compensation/providers/ppiu_direct_deposit/ppiu_provider'
require 'disability_compensation/providers/ppiu_direct_deposit/lighthouse_ppiu_provider'
require 'disability_compensation/providers/claims_service/claims_service_provider'
require 'disability_compensation/providers/claims_service/lighthouse_claims_service_provider'
require 'disability_compensation/providers/brd/brd_provider'
require 'disability_compensation/providers/brd/lighthouse_brd_provider'
require 'disability_compensation/providers/brd/lighthouse_staging_brd_provider'
require 'disability_compensation/providers/generate_pdf/generate_pdf_provider'
require 'disability_compensation/providers/generate_pdf/lighthouse_generate_pdf_provider'
require 'disability_compensation/providers/document_upload/lighthouse_supplemental_document_upload_provider'
require 'disability_compensation/providers/document_upload/evss_supplemental_document_upload_provider'
require 'logging/third_party_transaction'

class ApiProviderFactory
  extend Logging::ThirdPartyTransaction::MethodWrapper
  class UndefinedFactoryTypeError < StandardError; end

  API_PROVIDER = {
    evss: :evss,
    lighthouse: :lighthouse,
    lighthouse_staging: :lighthouse_staging
  }.freeze

  FACTORIES = {
    rated_disabilities: :rated_disabilities,
    intent_to_file: :intent_to_file,
    ppiu: :ppiu,
    claims: :claims,
    brd: :brd,
    generate_pdf: :generate_pdf,
    supplemental_document_upload: :supplemental_document_upload
  }.freeze

  FEATURE_TOGGLE_UPLOAD_BDD_INSTRUCTIONS = 'disability_compensation_upload_bdd_instructions_to_lighthouse'
  FEATURE_TOGGLE_UPLOAD_0781 = 'disability_compensation_upload_0781_to_lighthouse'
  FEATURE_TOGGLE_SUBMIT_VETERAN_UPLOADS = 'disability_compensation_upload_veteran_evidence_to_lighthouse'

  attr_reader :type

  wrap_with_logging(
    :rated_disabilities_service_provider,
    :intent_to_file_service_provider,
    :ppiu_service_provider,
    :claims_service_provider,
    :brd_service_provider,
    :generate_pdf_service_provider,
    :supplemental_document_upload_service_provider,
    additional_class_logs: {
      action: 'disability compensation factory choosing API Provider'
    },
    additional_instance_logs: {
      provider: %i[api_provider],
      factory: %i[type]
    }
  )

  def self.call(**)
    new(**).call
  end

  def initialize(type:, current_user:, feature_toggle: nil, provider: nil, options: {})
    @type = type
    @api_provider = provider
    @options = options
    # current user is necessary for the Flipper toggle to check against
    @current_user = current_user
    # for now, rated disabilities is the only special case that needs the feature toggle name sent in
    @feature_toggle = feature_toggle
  end

  def call
    case @type
    when FACTORIES[:rated_disabilities]
      rated_disabilities_service_provider
    when FACTORIES[:intent_to_file]
      intent_to_file_service_provider
    when FACTORIES[:ppiu]
      ppiu_service_provider
    when FACTORIES[:claims]
      claims_service_provider
    when FACTORIES[:brd]
      brd_service_provider
    when FACTORIES[:generate_pdf]
      generate_pdf_service_provider
    when FACTORIES[:supplemental_document_upload]
      supplemental_document_upload_service_provider
    else
      raise UndefinedFactoryTypeError
    end
  end

  private

  def rated_disabilities_service_provider
    case api_provider
    when API_PROVIDER[:lighthouse]
      LighthouseRatedDisabilitiesProvider.new(@options[:icn])
    else
      raise NotImplementedError, 'No known Rated Disabilities Api Provider type provided'
    end
  end

  def intent_to_file_service_provider
    case api_provider
    when API_PROVIDER[:lighthouse]
      LighthouseIntentToFileProvider.new(@current_user)
    else
      raise NotImplementedError, 'No known Intent to File Api Provider type provided'
    end
  end

  def ppiu_service_provider
    case api_provider
    when API_PROVIDER[:lighthouse]
      LighthousePPIUProvider.new(@current_user)
    else
      raise NotImplementedError, 'No known PPIU Api Provider type provided'
    end
  end

  def claims_service_provider
    case api_provider
    when API_PROVIDER[:lighthouse]
      LighthouseClaimsServiceProvider.new(@options[:icn])
    else
      raise NotImplementedError, 'No known Claims Service Api Provider type provided'
    end
  end

  def brd_service_provider
    case api_provider
    when API_PROVIDER[:lighthouse]
      LighthouseBRDProvider.new(@current_user)
    when API_PROVIDER[:lighthouse_staging]
      LighthouseStagingBRDProvider.new(@current_user)
    else
      raise NotImplementedError, 'No known BRD Api Provider type provided'
    end
  end

  def generate_pdf_service_provider
    case api_provider
    when API_PROVIDER[:lighthouse]
      LighthouseGeneratePdfProvider.new(@current_user[:icn])
    else
      raise NotImplementedError, 'No known Generate Pdf Api Provider type provided'
    end
  end

  def supplemental_document_upload_service_provider
    provider_options = [
      @options[:form526_submission],
      @options[:document_type],
      @options[:statsd_metric_prefix],
      @options[:supporting_evidence_attachment]
    ]

    case api_provider
    when API_PROVIDER[:evss]
      EVSSSupplementalDocumentUploadProvider.new(*provider_options)
    when API_PROVIDER[:lighthouse]
      LighthouseSupplementalDocumentUploadProvider.new(*provider_options)
    else
      raise NotImplementedError, 'No known Supplemental Document Upload Api Provider type provided'
    end
  end

  def api_provider
    @api_provider ||= if Flipper.enabled?(@feature_toggle, @current_user)
                        API_PROVIDER[:lighthouse]
                      else
                        API_PROVIDER[:evss]
                      end
  end
end
