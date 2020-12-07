# frozen_string_literal: true

module CovidVaccine
  class RegistrationSubmissionSerializer < ActiveModel::Serializer
    attribute :created_at

    def id
      object.sid
    end
  end
end
