# frozen_string_literal: true

module CovidVaccine
  module V0
    class RegistrationSubmissionSerializer < ActiveModel::Serializer
      attribute :created_at

      def id
        object.sid
      end
    end
  end
end
