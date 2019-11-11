# frozen_string_literal: true

require 'common/models/form'
require 'common/models/attribute_types/httpdate'

module VAOS
  class Facility < Common::Form
    include ActiveModel::Validations

    attribute :facility_address, String
    attribute :facility_city, String
    attribute :facility_state, String
    attribute :facility_code, String
    attribute :facility_name, String
    attribute :facility_parent_site_code, String
    attribute :facility_type, String
  end
end
