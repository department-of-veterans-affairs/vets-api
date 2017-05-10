# frozen_string_literal: true
require 'common/models/form'

module MHVAC
  class UpgradeForm < Common::Form
    attribute :user_id, Integer
    attribute :form_signed_date_time, String
    attribute :form_upgrade_manual_date, String
    attribute :form_upgrade_online_date, String
    attribute :terms_version, String

    def params
      Hash[attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact]
    end
  end
end
