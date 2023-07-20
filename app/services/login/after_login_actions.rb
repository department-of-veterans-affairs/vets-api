# frozen_string_literal: true

require 'login/errors'

module Login
  class AfterLoginActions
    include Accountable

    attr_reader :current_user

    def initialize(user)
      @current_user = user
    end

    def perform
      return unless current_user

      Login::UserCredentialEmailUpdater.new(credential_email: current_user.email,
                                            user_verification: current_user.user_verification).perform
      Login::UserAcceptableVerifiedCredentialUpdater.new(user_account: @current_user.user_account).perform
      update_account_login_stats(login_type)
      id_mismatch_validations

      AcceptableVerifiedCredentialAdoptionService.new(current_user).perform if
        Flipper.enabled?(:reactivation_experiment_initial_gate, current_user)

      if Settings.test_user_dashboard.env == 'staging'
        TestUserDashboard::UpdateUser.new(current_user).call(Time.current)
        TestUserDashboard::AccountMetrics.new(current_user).checkout
      end
    end

    private

    def login_type
      @login_type ||= current_user.identity.sign_in[:service_name]
    end

    def id_mismatch_validations
      return unless current_user.loa3?

      check_id_mismatch(current_user.identity.ssn, current_user.ssn_mpi, 'User Identity & MPI SSN values conflict')
      check_id_mismatch(current_user.identity.icn, current_user.mpi_icn, 'User Identity & MPI ICN values conflict')
      check_id_mismatch(current_user.identity.edipi, current_user.edipi_mpi,
                        'User Identity & MPI EDIPI values conflict')
      check_id_mismatch(current_user.identity.mhv_correlation_id, current_user.mpi_mhv_correlation_id,
                        'User Identity & MPI MHV Correlation ID values conflict')
    end

    def check_id_mismatch(identity_value, mpi_value, error_message)
      return if mpi_value.blank?

      if identity_value != mpi_value
        error_data = { icn: current_user.icn }
        error_data.merge!(identity_value:, mpi_value:) unless error_message.include?('SSN')
        Rails.logger.warn("[SessionsController version:v1] #{error_message}", error_data)
      end
    end
  end
end
