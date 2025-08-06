# frozen_string_literal: true

require 'vets/model'
require 'bid/awards/service'

class FormProfiles::VA686c674v2 < FormProfile
  class FormAddress
    include Vets::Model

    attribute :country_name, String
    attribute :address_line1, String
    attribute :address_line2, String
    attribute :address_line3, String
    attribute :city, String
    attribute :state_code, String
    attribute :province, String
    attribute :zip_code, String
    attribute :international_postal_code, String
  end

  attribute :form_address, FormAddress

  def prefill
    prefill_form_address

    super
  end

  def metadata
    {
      version: 0,
      prefill: true,
      returnUrl: '/686-options-selection'
    }
  end

  private

  def prefill_form_address
    begin
      mailing_address = if user.icn.present? && Flipper.enabled?(:remove_pciu, user)
                          VAProfileRedis::V2::ContactInformation.for_user(user).mailing_address
                        elsif user.vet360_id.present?
                          VAProfileRedis::ContactInformation.for_user(user).mailing_address
                        end
    rescue
      nil
    end

    return if mailing_address.blank?

    @form_address = FormAddress.new(
      mailing_address.to_h.slice(
        :address_line1, :address_line2, :address_line3,
        :city, :state_code, :province,
        :zip_code, :international_postal_code
      ).merge(country_name: mailing_address.country_code_iso3)
    )
  end

  def va_file_number_last_four
    response = BGS::People::Request.new.find_person_by_participant_id(user:)
    (
      response.file_number.presence || user.ssn.presence
    )&.last(4)
  end

  # @return [Integer] 1 if user is in receipt of pension, 0 if not, -1 if request fails
  # Needed for FE to differentiate between 200 response and error
  def is_in_receipt_of_pension
    case awards_pension[:is_in_receipt_of_pension]
    when true
      1
    when false
      0
    else
      -1
    end
  end

  # @return [Integer] the net worth limit for pension, default is 159240 as of 2025 
  # Default will be cached in future enhancement
  def net_worth_limit
    awards_pension[:net_worth_limit] || 159240
  end

  # @return [Hash] the awards pension data from BID service or an empty hash if the request fails
  def awards_pension
    @awards_pension ||= begin
      response = pension_award_service.get_awards_pension
      response.try(:body)&.dig('awards_pension')&.transform_keys(&:to_sym)
    rescue
      {}
    end
  end

  def pension_award_service
    @pension_award_service ||= BID::Awards::Service.new(user)
  end
end
