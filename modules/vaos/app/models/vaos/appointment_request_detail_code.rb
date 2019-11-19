# frozen_string_literal: true

require 'common/models/form'

module VAOS
  class Patient < Common::Form
    include ActiveModel::Validations

    attribute :display_name, String
    attribute :first_name, String
    attribute :last_name, String
    attribute :date_of_birth, String  # Jan 01, 1962
    attribute :ssn, String
    attribute :inpatient, Boolean
    attribute :text_messaging_allowed, Boolean
    attribute :id, String
    attribute :object_type, String
  end
end
