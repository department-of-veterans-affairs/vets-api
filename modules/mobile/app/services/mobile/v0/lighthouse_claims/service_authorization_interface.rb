# frozen_string_literal: true

require 'lighthouse/facilities/client'
require 'lighthouse/benefits_claims/service'
require_relative '../claims/proxy'

module Mobile
  class ServiceAuthorizationInterface
    def initialize(user)
      @current_user = user
    end

    def get_accessible_claims_appeals(use_cache)
      if claims_access? && appeals_access?
        service.get_claims_and_appeals(use_cache)
      elsif claims_access?
        service.get_claims(use_cache)
      elsif appeals_access?
        service.get_appeals(use_cache)
      else
        raise Pundit::NotAuthorizedError
      end
    end

    def get_claim
      response = service.get_claim(params[:id])
      claim_status_lighthouse? ? lighthouse_claims_adapter.parse(response) : response
    end

    def request_decision
      response = service.request_decision(params[:id])
      request_decision_lighthouse? ? adapt_response(response) : response
    end

    def upload_document
      if upload_document_lighthouse?
        set_params
        lighthouse_document_service.queue_document_upload(params)
      else
        evss_claims_proxy.upload_document(params)
      end
    end

    def upload_multi_image_document
      if upload_document_lighthouse?
        set_params
        lighthouse_document_service.queue_multi_image_upload_document(params)
      else
        evss_claims_proxy.upload_multi_image(params)
      end
    end

    def set_params
      params[:claim_id] = params[:id]
      params[:tracked_item_ids] = Array.wrap(tracked_item_id) if tracked_item_id.present?
      params.delete(:tracked_item_id)
      params.delete(:trackedItemId)
    end

    # It was found that FE is using both different casing between multi image upload and single image upload.
    # This shouldn't matter due to the x-key-inflection: camel header being used but that header only works if the
    # body payload is in json, which the single doc upload is not (at least in specs for both LH and EVSS).
    def tracked_item_id
      params[:trackedItemId] || params[:tracked_item_id]
    end

    delegate :cleanup_after_upload, to: :document_service

    def claims_access?
      if claim_status_lighthouse?
        @current_user.authorize(:lighthouse,
                                :access?)
      else
        @current_user.authorize(:evss, :access?)
      end
    end

    def request_decision_access?
      if request_decision_lighthouse?
        @current_user.authorize(:lighthouse,
                                :access?)
      else
        @current_user.authorize(:evss, :access?)
      end
    end

    def upload_document_access?
      if upload_document_lighthouse?
        @current_user.authorize(:lighthouse,
                                :access?)
      else
        @current_user.authorize(:evss, :access?)
      end
    end

    def appeals_access?
      @current_user.authorize(:appeals, :access?)
    end

    def claim_status_lighthouse?
      Flipper.enabled?(:mobile_lighthouse_claims, @current_user)
    end

    def request_decision_lighthouse?
      Flipper.enabled?(:mobile_lighthouse_request_decision, @current_user)
    end

    def upload_document_lighthouse?
      Flipper.enabled?(:mobile_lighthouse_document_upload, @current_user)
    end

    def non_authorization_errors?(service_errors)
      return false unless service_errors

      authorization_errors = [Mobile::V0::Claims::Proxy::CLAIMS_NOT_AUTHORIZED_MESSAGE,
                              Mobile::V0::Claims::Proxy::APPEALS_NOT_AUTHORIZED_MESSAGE]
      !service_errors.all? { |error| authorization_errors.include?(error[:error_details]) }
    end

    def document_service
      upload_document_lighthouse? ? lighthouse_document_service : evss_claims_proxy
    end

    def service
      claim_status_lighthouse? ? lighthouse_claims_proxy : evss_claims_proxy
    end

    def lighthouse_claims_proxy
      Mobile::V0::LighthouseClaims::Proxy.new(@current_user)
    end

    def evss_claims_proxy
      @claims_proxy ||= Mobile::V0::Claims::Proxy.new(@current_user)
    end

    def lighthouse_document_service
      @lighthouse_document_service ||= BenefitsDocuments::Service.new(@current_user)
    end

    def lighthouse_claims_adapter
      Mobile::V0::Adapters::LighthouseIndividualClaims.new
    end

    private

    def adapt_response(response)
      response['success'] ? 'success' : 'failure'
    end
  end
end
