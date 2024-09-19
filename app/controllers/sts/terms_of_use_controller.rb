# frozen_string_literal: true

module Sts
  class TermsOfUseController < SignIn::ServiceAccountApplicationController
    service_tag 'identity'
    before_action :set_current_terms_of_use_agreement, only: %i[current_status]

    def current_status
      Rails.logger.info('[Sts][TermsOfUseController] current_status success', icn:)
      render json: { agreement_status: @current_terms_of_use_agreement&.response }, status: :ok
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
  end
end
