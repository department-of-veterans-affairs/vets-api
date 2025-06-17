# frozen_string_literal: true

module Audit
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    connects_to database: { writing: :audit, reading: :audit }
  end
end
