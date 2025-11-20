# frozen_string_literal: true

module Form526MPIConcern
  extend ActiveSupport::Concern

  def mpi_service
    @mpi_service ||= MPI::Service.new
  end

  def get_icn_from_mpi
    edipi_response_profile = edipi_mpi_profile_query(auth_headers['va_eauth_dodedipnid'])
    if edipi_response_profile&.icn.present?
      OpenStruct.new(icn: edipi_response_profile.icn)
    else
      Rails.logger.info('Form526Submission::account - unable to look up MPI profile with EDIPI', log_payload)
      attributes_response_profile = attributes_mpi_profile_query(auth_headers)
      if attributes_response_profile&.icn.present?
        OpenStruct.new(icn: attributes_response_profile.icn)
      else
        Rails.logger.info('Form526Submission::account - no ICN present', log_payload)
        OpenStruct.new(icn: nil)
      end
    end
  end

  def edipi_mpi_profile_query(edipi)
    return unless edipi

    edipi_response = mpi_service.find_profile_by_edipi(edipi:)
    edipi_response.profile if edipi_response.ok? && edipi_response.profile.icn.present?
  end

  def attributes_mpi_profile_query(auth_headers)
    required_attributes = %w[va_eauth_firstName va_eauth_lastName va_eauth_birthdate va_eauth_pnid]
    return unless required_attributes.all? { |attr| auth_headers[attr].present? }

    attributes_response = mpi_service.find_profile_by_attributes(
      first_name: auth_headers['va_eauth_firstName'],
      last_name: auth_headers['va_eauth_lastName'],
      birth_date: auth_headers['va_eauth_birthdate']&.to_date.to_s,
      ssn: auth_headers['va_eauth_pnid']
    )
    attributes_response.profile if attributes_response.ok? && attributes_response.profile.icn.present?
  end
end
