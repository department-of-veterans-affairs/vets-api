# frozen_string_literal: true

require 'vets/model'

module MHVAC
  ##
  # Models a MHVAC (MyHealtheVet Account Creation) upgrade form.
  #
  # @!attribute user_id
  #   @return [Integer]
  # @!attribute form_signed_date_time
  #   @return [Vets::Type::HTTPDate]
  # @!attribute form_upgrade_manual_date
  #   @return [Vets::Type::HTTPDate]
  # @!attribute form_upgrade_online_date
  #   @return [Vets::Type::HTTPDate]
  # @!attribute terms_version
  #   @return [String]
  #
  class UpgradeForm
    include Vets::Model

    attribute :user_id, Integer
    attribute :form_signed_date_time, Vets::Type::HTTPDate
    attribute :form_upgrade_manual_date, Vets::Type::HTTPDate
    attribute :form_upgrade_online_date, Vets::Type::HTTPDate
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

      self.class.attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact.to_h
    end
  end
end
