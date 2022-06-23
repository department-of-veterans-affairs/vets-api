# frozen_string_literal: true

module SignIn
  class CredentialLevelCreator
    attr_reader :requested_acr, :type, :id_token, :user_info

    def initialize(requested_acr:, type:, id_token:, user_info:)
      @requested_acr = requested_acr
      @type = type
      @id_token = id_token
      @user_info = user_info
    end

    def perform
      create_credential_level
    end

    private

    def create_credential_level
      CredentialLevel.new(requested_acr: requested_acr,
                          credential_type: type,
                          current_ial: current_ial,
                          max_ial: max_ial)
    rescue ActiveModel::ValidationError
      raise Errors::InvalidCredentialLevelError, 'Unsupported credential authorization levels'
    end

    def max_ial
      if type == 'logingov'
        user_info[:verified_at] ? IAL::TWO : IAL::ONE
      else
        user_info.level_of_assurance == LOA::THREE ? IAL::TWO : IAL::ONE
      end
    end

    def current_ial
      if type == 'logingov'
        acr = JWT.decode(id_token, nil, false).first['acr']
        acr == IAL::LOGIN_GOV_IAL2 ? IAL::TWO : IAL::ONE
      else
        user_info.credential_ial == LOA::IDME_CLASSIC_LOA3 ? IAL::TWO : IAL::ONE
      end
    end
  end
end
