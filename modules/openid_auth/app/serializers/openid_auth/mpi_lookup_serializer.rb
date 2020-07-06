# frozen_string_literal: true

module OpenidAuth
  class MPILookupSerializer < ActiveModel::Serializer
    type 'user-mvi-icn'

    def id
      object.profile.icn
    end

    attributes :icn, :first_name, :last_name

    def icn
      object.profile.icn
    end

    def first_name
      object.profile&.given_names&.first
    end

    def last_name
      object.profile&.family_name
    end
  end
end
