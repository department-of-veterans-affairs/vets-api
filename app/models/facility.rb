# frozen_string_literal: true
require 'common/models/base'

class Facility < Common::Base
  attribute :begin_date, String
  attribute :name, String
  attribute :code, String

  # validates :begin_date, presence: true
  # validates :name, presence: true
end
