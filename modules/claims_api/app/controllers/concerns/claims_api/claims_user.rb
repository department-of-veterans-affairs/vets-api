# frozen_string_literal: true

module ClaimsApi
  class ClaimsUser
    def initialize(id)
      @uuid = id
      @identifier = UserIdentifier.new(id)
    end

    def set_validated_token(validated_token)
      @validated_token = validated_token
    end

    def set_icn(icn)
      @identifier.set_icn(icn)
    end

    def set_ssn(ssn)
      @identifier.set_ssn(ssn)
    end

    def icn
      @identifier.icn
    end

    def loa
      @identifier.loa
    end

    attr_reader :uuid
    attr_accessor :first_name, :last_name, :middle_name, :email

    def authn_context
      'authn'
    end

    def mhv_icn
      @identifier.icn
    end

    def first_name_last_name(first_name, last_name)
      @first_name = first_name
      @last_name = last_name
      @identifier.first_name_last_name(first_name, last_name)
    end

    def ssn
      @identifier.ssn
    end

    def client_credentials_token?
      @validated_token.client_credentials_token?
    end
  end
end
