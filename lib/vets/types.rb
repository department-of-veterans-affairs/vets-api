# frozen_string_literal: true

# These are the castable type and
# types that can be used by Vets::Attributes
# Primitive types include:
#  String, Integer, Float, Date, Time, DateTime, Bool

require 'vets/type/array'
require 'vets/type/base'
require 'vets/type/date_time_string'
require 'vets/type/hash'
require 'vets/type/http_date'
require 'vets/type/iso8601_time'
require 'vets/type/object'
require 'vets/type/primitive'
require 'vets/type/titlecase_string'
require 'vets/type/utc_time'

module Vets
  module Types
  end
end
