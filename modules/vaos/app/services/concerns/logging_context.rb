# frozen_string_literal: true

module VAOS
  ##
  # Provides helper methods for accessing logging context information
  # such as controller name, station number, and EPS trace ID.
  #
  # This concern can be included in any service class that needs to
  # add contextual information to logs.
  #
  module LoggingContext
    ##
    # Returns the controller name from RequestStore for logging context
    #
    # @return [String, nil] The controller name or nil if not set
    #
    def controller_name
      RequestStore.store['controller_name']
    end

    ##
    # Returns the user's primary station number (first treatment facility ID) for logging context
    #
    # @param user [User] The user object (optional, will try to use @user or @current_user if not provided)
    # @return [String, nil] The station number or nil if not available
    #
    def station_number(user = nil)
      user_obj = user || @user || @current_user
      user_obj&.va_treatment_facility_ids&.first
    end

    ##
    # Returns the EPS trace ID from RequestStore
    #
    # @return [String, nil] The trace ID or nil if not set
    #
    def eps_trace_id
      RequestStore.store['eps_trace_id']
    end
  end
end
