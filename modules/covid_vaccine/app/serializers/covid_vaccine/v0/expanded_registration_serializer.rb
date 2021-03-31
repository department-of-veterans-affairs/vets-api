# frozen_string_literal: true

module CovidVaccine
  module V0
    class ExpandedRegistrationSerializer < ActiveModel::Serializer
      attribute :created_at

      def id
        nil
      end
    end
  end
end
