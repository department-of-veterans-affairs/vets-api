# frozen_string_literal: true

module ClaimsApi
  class ClaimsUser
    attr_reader :uuid
    attr_accessor :first_name, :last_name, :middle_name, :email, :suffix

    def initialize(id)
      @uuid = id
      @identifier = UserIdentifier.new(id)
    end

    def set_validated_token(validated_token)
      @validated_token = validated_token
    end

    delegate :set_icn, to: :@identifier

    delegate :set_ssn, to: :@identifier

    delegate :icn, to: :@identifier

    delegate :loa, to: :@identifier

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

    delegate :ssn, to: :@identifier

    delegate :client_credentials_token?, to: :@validated_token
  end
end
