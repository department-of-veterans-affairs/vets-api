# frozen_string_literal: true

class IvcChampvaForm < ApplicationRecord
  validates :form_uuid, presence: true, uniqueness: { case_sensitive: false }

end
