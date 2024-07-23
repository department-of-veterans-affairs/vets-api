# frozen_string_literal: true

module Vye
  class Vye::PendingDocument < ApplicationRecord
    belongs_to :user_profile

    validates :doc_type, :queue_date, :rpo, presence: true
  end
end
