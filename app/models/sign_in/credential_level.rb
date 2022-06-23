# frozen_string_literal: true

module SignIn
  class CredentialLevel
    include ActiveModel::Validations

    attr_reader(
      :requested_acr,
      :current_ial,
      :max_ial,
      :credential_type
    )

    validates(:requested_acr, inclusion: { in: Constants::Auth::ACR_VALUES })
    validates(:credential_type, inclusion: { in: Constants::Auth::REDIRECT_URLS })
    validates(:current_ial, inclusion: { in: [IAL::ONE, IAL::TWO] })
    validates(:max_ial, inclusion: { in: [IAL::ONE, IAL::TWO] })

    def initialize(requested_acr:, credential_type:, current_ial:, max_ial:)
      @requested_acr = requested_acr
      @credential_type = credential_type
      @current_ial = current_ial
      @max_ial = max_ial

      validate!
    end

    def can_uplevel_credential?
      requested_acr == 'min' && current_ial < max_ial
    end

    def persisted?
      false
    end
  end
end
