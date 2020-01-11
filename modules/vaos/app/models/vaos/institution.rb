# frozen_string_literal: true

require 'common/models/base'

module VAOS
  class Institution < Common::Base
    attribute :location_ien, String
    attribute :institution_sid, Integer
    attribute :institution_ien, String
    attribute :institution_name, String
    attribute :institution_code, String
  end
end
