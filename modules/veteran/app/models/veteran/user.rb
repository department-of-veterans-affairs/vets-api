# frozen_string_literal: true

require 'bgs_service/local_bgs'

# Veteran model
module Veteran
  class User < Base
    attr_accessor :power_of_attorney, :previous_power_of_attorney

    def initialize(user)
      @user = user

      if current_poa_code.present?
        self.power_of_attorney = PowerOfAttorney.new(code: current_poa_code,
                                                     begin_date: current_poa_information[:begin_date])
      end
      self.previous_power_of_attorney = PowerOfAttorney.new(code: previous_poa_code) if previous_poa_code.present?
    end

    private

    def current_poa_code
      return nil unless current_poa_information.present? && current_poa_information[:person_org_name].present?

      current_poa_information[:person_org_name]&.split&.first
    end

    def current_poa_information
      @current_poa_information ||= local_bgs_service.find_poa_by_participant_id(@user.participant_id)
    end

    def previous_poa_code
      return @previous_poa_code if @previous_poa_code.present?

      poa_history = local_bgs_service.find_poa_history_by_ptcpnt_id(@user.participant_id)
      return nil if poa_history[:person_poa_history].blank?

      # Sorts previous power of attorneys by begin date
      poa_history = poa_history[:person_poa_history][:person_poa]
      poa_history = [poa_history] unless poa_history.is_a?(Array)
      poa_history = poa_history.select { |poa| poa[:begin_dt].present? }.sort_by { |poa| poa[:begin_dt] }.reverse
      poa_codes = poa_history.pluck(:legacy_poa_cd)

      @previous_poa_code = poa_codes.delete_if { |poa_code| poa_code == current_poa_code }.first
    end

    def bgs_service
      external_key = "#{@user.first_name} #{@user.last_name}"
      @bgs_service ||= BGS::Services.new(
        external_uid: @user.mpi_icn,
        external_key: external_key.presence || @user.mpi_icn
      )
    end

    def local_bgs_service
      external_key = "#{@user.first_name} #{@user.last_name}"
      @local_bgs_service ||= ClaimsApi::LocalBGS.new(
        external_uid: @user.mpi_icn,
        external_key: external_key.presence || @user.mpi_icn
      )
    end
  end
end
