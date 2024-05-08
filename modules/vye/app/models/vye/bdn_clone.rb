# frozen_string_literal: true

class Vye::BdnClone < ApplicationRecord
  has_many :user_infos, dependent: :destroy
end
