# frozen_string_literal: true

module SignIn
  class CredentialLevel
    include ActiveModel::Validations

    attr_reader(
      :requested_acr,
      :current_ial,
      :max_ial,
      :credential_type,
      :auto_uplevel
    )

    validates(:requested_acr, inclusion: { in: Constants::Auth::ACR_VALUES })
    validates(:credential_type, inclusion: { in: Constants::Auth::REDIRECT_URLS })
    validates(:current_ial, inclusion: { in: [IAL::ONE, IAL::TWO] })
    validates(:max_ial, inclusion: { in: [IAL::ONE, IAL::TWO] })
    validate(:max_ial_greater_than_or_equal_to_current_ial)

    def initialize(requested_acr:, credential_type:, current_ial:, max_ial:, auto_uplevel: false)
      @requested_acr = requested_acr
      @credential_type = credential_type
      @current_ial = current_ial
      @max_ial = max_ial
      @auto_uplevel = auto_uplevel

      validate!
    end

    def can_uplevel_credential?
      requested_acr == 'min' && current_ial < max_ial
    end

    private

    def persisted?
      false
    end

    def max_ial_greater_than_or_equal_to_current_ial
      errors.add(:max_ial, 'cannot be less than Current ial') if max_ial.to_i < current_ial.to_i
    end
  end
end
