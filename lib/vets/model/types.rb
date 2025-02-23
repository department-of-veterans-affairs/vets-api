# frozen_string_literal: true

# These are the castable type and
# types that can be used by Vets::Model::Attributes
# Primitive types include:
#  String, Integer, Float, Date, Time, DateTime, Bool

require 'vets/model/type/date_time_string'
require 'vets/model/type/hash'
require 'vets/model/type/http_date'
require 'vets/model/type/iso8601_time'
require 'vets/model/type/object'
require 'vets/model/type/primitive'
require 'vets/model/type/titlecase_string'
require 'vets/model/type/utc_time'
require 'vets/model/type/array'
