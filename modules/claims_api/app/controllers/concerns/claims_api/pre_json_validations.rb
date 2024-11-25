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
      validate_form_email(veteran_email, 'veteran') if veteran_email

      claimant_email = @json_body.dig('data', 'attributes', 'claimant', 'email')
      validate_form_email(claimant_email, 'claimant') if claimant_email

      org_email = @json_body.dig('data', 'attributes', 'serviceOrganization', 'email')
      validate_form_email(org_email, 'serviceOrganization') if org_email

      @json_body
    end

    def validate_form_email(email, field)
      @json_body.dig('data', 'attributes', field).delete('email') if email.blank?
    end
  end
end
