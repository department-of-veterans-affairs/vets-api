# frozen_string_literal: true

module Vye
  class BndCloneNotFound < StandardError; end

  class Vye::BdnClone < ApplicationRecord
    has_many :user_infos, dependent: :destroy

    # BDN Clone Stages
    # |----------------------------------------------------------|
    # | is_active | export_ready | description                   |
    # |-----------|--------------|-------------------------------|
    # | false     |   nil        | fresh import                  |
    # | true      |   nil        | currently active              |
    # | nil       |   true       | ready to be exported          |
    # | nil       |   false      | there was a problem exporting |
    # | nil       |   nil        | to be removed                 |
    # |----------------------------------------------------------|

    validates :is_active, :export_ready, uniqueness: true, allow_nil: true

    validates :transact_date, presence: true

    def self.activate_injested!
      Rails.logger.info 'Vye::BdnClone.activate_injested! starting'
      injested = where(is_active: false).first

      if injested.present?
        injested.activate!
      else
        Rails.logger.error 'Vye::BdnClone: nothing found to activate'
        raise BndCloneNotFound
      end
      Rails.logger.info 'Vye::BdnClone.activate_injested! finished'
    end

    def self.clear_export_ready!
      where(export_ready: true).update!(export_ready: nil)
    end

    def activate!
      user_info_count = 0
      Rails.logger.info 'Vye::BdnClone: proceeding with activation'
      transaction do
        old = self.class.find_by(is_active: true)

        if old.present?
          old.update!(is_active: nil, export_ready: true)
          # rubocop:disable Rails/SkipsModelValidations
          UserInfo.where(bdn_clone_id: old.id).update_all(bdn_clone_active: nil)
          # rubocop:enable Rails/SkipsModelValidations
        end

        update!(is_active: true)
        # rubocop:disable Rails/SkipsModelValidations
        user_info_count = UserInfo.where(bdn_clone_id: id).update_all(bdn_clone_active: true)
        # rubocop:enable Rails/SkipsModelValidations
      end
      Rails.logger.info "Vye::BdnClone: activation complete with #{user_info_count} user_info records"
      user_info_count
    rescue
      Rails.logger.error 'Vye::BdnClone: there was a problem during activation'
      raise
    end
  end
end
