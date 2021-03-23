# frozen_string_literal: true

module Identity
  class User
    attr_accessor  :uuid, :first_name, :last_name, :email

    delegate :relationships, to: :identity
    delegate :identifiers,   to: :identity
    delegate :addresses,     to: :identity
    delegate :phones,        to: :identity

    def initialize(attrs={})
      @uuid       = attrs[:uuid]
      @first_name = attrs[:first_name]
      @last_name  = attrs[:last_name]
      @email      = attrs[:email]
      @identity   = attrs[:identity]
    end

    def id
      uuid
    end

    # Permission to view the Identity
    def can_view?(uuid)
      relationships.map(&:uuid).include?(uuid)
    end
  end
end
