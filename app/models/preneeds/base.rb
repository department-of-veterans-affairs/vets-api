# frozen_string_literal: true
require 'common/models/form'

module Preneeds
  class Base
    extend ActiveModel::Naming
    include Virtus.model(nullify_blank: true)
  end
end
