# frozen_string_literal: true
require 'common/models/form'

module MHVAC
  class UpgradeForm < Common::Form
    attribute :user_id, Integer
    attribute :form_signed_date_time, String
    attribute :form_upgrade_manual_date, String
    attribute :form_upgrade_online_date, String
    attribute :terms_version, String

    # TODO: the above attrs will be camelcased by middleware
    def params
      { }
    end
  end
end
