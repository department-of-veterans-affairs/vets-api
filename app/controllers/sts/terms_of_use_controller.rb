# frozen_string_literal: true

require 'mhv/account_creation/configuration'

module Sts
  class TermsOfUseController < SignIn::ServiceAccountApplicationController
    service_tag 'identity'
    before_action :set_current_terms_of_use_agreement, only: %i[current_status]

    def current_status
      Rails.logger.info('[Sts][TermsOfUseController] current_status success', icn:)

      render json: serialized_response, status: :ok
    end

    private

    def set_current_terms_of_use_agreement
      @current_terms_of_use_agreement = TermsOfUseAgreement.joins(:user_account)
                                                           .where(user_account: { icn: })
                                                           .current.last
    end

    def icn
      @service_account_access_token.user_attributes['icn']
    end

    def serialized_response
      {
        agreement_status: @current_terms_of_use_agreement&.response
      }.tap { |h| h[:metadata] = metadata if include_metadata? }
    end

    def include_metadata?
      params[:metadata] == 'true' && @current_terms_of_use_agreement&.accepted?
    end

    def metadata
      {
        va_terms_of_use_doc_title: MHV::AccountCreation::Configuration::TOU_DOC_TITLE,
        va_terms_of_use_legal_version: MHV::AccountCreation::Configuration::TOU_LEGAL_VERSION,
        va_terms_of_use_revision: MHV::AccountCreation::Configuration::TOU_REVISION,
        va_terms_of_use_status: MHV::AccountCreation::Configuration::TOU_STATUS,
        va_terms_of_use_datetime: @current_terms_of_use_agreement&.created_at
      }
    end
  end
end
