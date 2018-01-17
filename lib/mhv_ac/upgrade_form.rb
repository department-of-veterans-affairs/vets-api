# frozen_string_literal: true

require 'common/models/form'
require 'common/models/attribute_types/httpdate'

module MHVAC
  class UpgradeForm < Common::Form
    include ActiveModel::Validations

    attribute :user_id, Integer
    attribute :form_signed_date_time, Common::HTTPDate
    attribute :form_upgrade_manual_date, Common::HTTPDate
    attribute :form_upgrade_online_date, Common::HTTPDate
    attribute :terms_version, String

    validates :user_id, :terms_version, :form_signed_date_time, presence: true

    def mhv_params
      raise Common::Exceptions::ValidationErrors, self unless valid?
      Hash[attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact]
    end
  end
end
