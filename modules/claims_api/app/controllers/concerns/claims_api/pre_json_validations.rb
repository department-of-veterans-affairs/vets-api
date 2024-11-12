# frozen_string_literal: true

module ClaimsApi
  module PreJsonValidations
    # V1 JSON Schema enforces a regex pattern if the email is included
    # it must  have '.@.' in it.
    # This allows for submissions with an empty str for email to move past that validation
    def pre_json_verification_of_email_for_poa
      form = @json_body.dig('data', 'type') || {}
      return @json_body unless form == 'form/21-22'

      veteran_email = @json_body.dig('data', 'attributes', 'veteran', 'email')
      validate_veteran_form_email(veteran_email) if veteran_email

      claimant_email = @json_body.dig('data', 'attributes', 'claimant', 'email')
      validate_claimant_form_email(claimant_email) if claimant_email

      org_email = @json_body.dig('data', 'attributes', 'serviceOrganization', 'email')
      validate_service_organization_form_email(org_email) if org_email

      @json_body
    end

    def validate_veteran_form_email(veteran_email)
      @json_body.dig('data', 'attributes', 'veteran').delete('email') if veteran_email.blank?
    end

    def validate_claimant_form_email(claimant_email)
      @json_body.dig('data', 'attributes', 'claimant').delete('email') if claimant_email.blank?
    end

    def validate_service_organization_form_email(org_email)
      @json_body.dig('data', 'attributes', 'serviceOrganization').delete('email') if org_email.blank?
    end
  end
end
