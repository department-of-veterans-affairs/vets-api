# frozen_string_literal: true

require 'benefits_claims/providers/benefits_claims/benefits_claims_provider'
require 'benefits_claims/providers/ivc_champva/claim_builder'
require 'benefits_claims/providers/ivc_champva/claim_serializer'

module BenefitsClaims
  module Providers
    module IvcChampva
      class IvcChampvaBenefitsClaimsProvider
        include BenefitsClaims::Providers::BenefitsClaimsProvider

        def initialize(user)
          @user = user
        end

        def get_claims
          return empty_response if user_emails.blank?

          claims = forms_grouped_by_uuid.map { |records| transform_to_dto(records) }

          { 'data' => claims }
        end

        def get_claim(id)
          return record_not_found!(id) if user_emails.blank?

          records = scoped_forms.where(form_uuid: id).order(:created_at)
          record_not_found!(id) if records.blank?

          { 'data' => transform_to_dto(records) }
        end

        private

        def transform_to_dto(records)
          dto = ClaimBuilder.build_claim_response(records)
          ClaimSerializer.to_json_api(dto)
        end

        def empty_response
          { 'data' => [] }
        end

        def record_not_found!(id)
          raise Common::Exceptions::RecordNotFound, id
        end

        def forms_grouped_by_uuid
          scoped_forms.order(:created_at).group_by(&:form_uuid).values
        end

        def scoped_forms
          IvcChampvaForm.where('LOWER(TRIM(email)) IN (?)', user_emails)
        end

        def user_emails
          @user_emails ||= begin
            verification_emails = @user&.user_account&.user_verifications&.includes(:user_credential_email)&.filter_map do |verification|
              verification.user_credential_email&.credential_email&.strip&.downcase
            end || []

            ([@user&.email&.strip&.downcase] + verification_emails).compact.uniq
          end
        end
      end
    end
  end
end
