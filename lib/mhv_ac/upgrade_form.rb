# frozen_string_literal: true

require 'common/models/form'
require 'common/models/attribute_types/httpdate'

module MHVAC
  ##
  # Models a MHVAC (MyHealtheVet Account Creation) upgrade form.
  #
  # @!attribute user_id
  #   @return [Integer]
  # @!attribute form_signed_date_time
  #   @return [Common::HTTPDate]
  # @!attribute form_upgrade_manual_date
  #   @return [Common::HTTPDate]
  # @!attribute form_upgrade_online_date
  #   @return [Common::HTTPDate]
  # @!attribute terms_version
  #   @return [String]
  #
  class UpgradeForm < Common::Form
    include ActiveModel::Validations

    attribute :user_id, Integer
    attribute :form_signed_date_time, Common::HTTPDate
    attribute :form_upgrade_manual_date, Common::HTTPDate
    attribute :form_upgrade_online_date, Common::HTTPDate
    attribute :terms_version, String

    validates :user_id, :terms_version, :form_signed_date_time, presence: true

    ##
    # Validates form attributes and wraps each present attribute to create
    # a parameter set for MHV, stripping attribute values of nil.
    #
    # @raise [Common::Exceptions::ValidationErrors] if there are validation errors
    # @return [Hash] A hash of valid form attributes
    #
    def mhv_params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      Hash[attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact]
    end
  end
end
