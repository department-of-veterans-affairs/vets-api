# frozen_string_literal: true

module Vye
  class Vye::BdnClone < ApplicationRecord
    has_many :user_infos, dependent: :destroy

    def activate!
      UserInfo.transaction do
        # rubocop:disable Rails/SkipsModelValidations
        UserInfo.update_all(bdn_clone_active: false)
        UserInfo.where(bdn_clone_id: id).update_all(bdn_clone_active: true)
        # rubocop:enable Rails/SkipsModelValidations
      end
    end
  end
end
