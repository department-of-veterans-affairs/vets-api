# frozen_string_literal: true

module AppealsApi
  class StatusUpdate < ApplicationRecord
    belongs_to :statusable, polymorphic: true, optional: true
  end
end
