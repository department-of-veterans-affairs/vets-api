# frozen_string_literal: true

# Service class for validating and creating a participant in MPI by ICN
# This class will propogate any error that occurs while being processed.
class MPIProxyPersonAdder
  attr_reader :user_account_uuid, :profile, :icn, :mpi_service

  # Retrieve user profile from MPI on instantiation
  def initialize(icn)
    @icn = icn
    @user_account_uuid = UserAccount.find_by(icn:)&.id
    @mpi_service = MPI::Service.new
  end

  ##
  # (see #add_person_proxy_by_icn)
  #
  # @param icn
  #
  def self.add_person_proxy_by_icn(icn)
    new(icn).add_person_proxy_by_icn
  end

  ##
  # Retrieve MPI profile for icn,
  # validate if able to run add_person_proxy, and only call MPI's
  # add_person_proxy if all validation checks pass. If checks don't
  # pass, then skip the add_person_proxy call.
  #
  def add_person_proxy_by_icn
    monitor.track_proxy_add_begun

    fetch_profile

    if profile.present? && MPIPolicy.new(profile).access_add_person_proxy?
      mpi_service.add_person_proxy(**add_person_proxy_params)
      monitor.track_proxy_add_success
      true
    else
      monitor.track_proxy_add_skipped
      false
    end
  rescue => e
    monitor.track_proxy_add_failure(e)
    raise e
  end

  private

  # Create instance Monitor
  def monitor
    @monitor ||= MPIProxyPersonAdder::Monitor.new(user_account_uuid)
  end

  ##
  # Function to fetch MPI profile by user's ICN.
  # If response returns an error, propogates the returned error.
  def fetch_profile
    raise ArgumentError, 'Unable to fetch MPI profile. Missing ICN.' if icn.blank?

    response = mpi_service.find_profile_by_identifier(
      identifier: icn,
      identifier_type: MPI::Constants::ICN
    )
    raise response.error if response.error.present?

    @profile = response.profile
  rescue MPI::Errors::RecordNotFound => e
    monitor.track_proxy_add_failure(e, 'No MPI profile found for given user account')
    raise e
  end

  # Necessary param list for MPI add_person_proxy call.
  def add_person_proxy_params
    {
      first_name: profile.given_names.first,
      last_name: profile.family_name,
      ssn: profile.ssn,
      birth_date: Formatters::DateFormatter.format_date(profile.birth_date),
      icn: profile.icn,
      edipi: profile.edipi,
      search_token: profile.search_token
    }
  end

  # Monitor/Logging functions
  class Monitor
    # statsd prefix
    STATSD_KEY_PREFIX = 'mpi_proxy.add_person_proxy_by_icn'

    # default message for skipped and failure
    DEFAULT_LOGGER_MESSAGE = 'Add person proxy by icn'

    # source for log messages
    MPI_PROXY_PERSON_ADDER_PATH = 'app/services/mpi_proxy_person_adder'

    attr_reader :user_account_uuid

    # create monitor instance
    def initialize(user_account_uuid)
      @user_account_uuid = user_account_uuid
    end

    # beginning proxy add
    def track_proxy_add_begun
      StatsD.increment("#{STATSD_KEY_PREFIX}.begun")
      Rails.logger.info("#{DEFAULT_LOGGER_MESSAGE} begun", context)
    end

    # successful proxy add
    def track_proxy_add_success
      StatsD.increment("#{STATSD_KEY_PREFIX}.success")
      Rails.logger.info("#{DEFAULT_LOGGER_MESSAGE} success", context)
    end

    # skipped proxy add
    #
    # @param message [String] custom message to be logged; default DEFAULT_LOGGER_MESSAGE
    #
    def track_proxy_add_skipped(message = nil)
      StatsD.increment("#{STATSD_KEY_PREFIX}.skipped")

      message ||= "#{DEFAULT_LOGGER_MESSAGE} skipped"
      Rails.logger.info(message, context)
    end

    # skipped proxy add
    #
    # @param error [Object] the 'error' to be logged
    # @param message [String] custom message to be logged; default DEFAULT_LOGGER_MESSAGE
    #
    def track_proxy_add_failure(error, message = nil)
      StatsD.increment("#{STATSD_KEY_PREFIX}.failure")

      message ||= "#{DEFAULT_LOGGER_MESSAGE} failure"
      Rails.logger.warn(message, { error: }.merge(context))
    end

    private

    # the monitor context to be logged
    def context
      {
        user_account_uuid:,
        source: MPI_PROXY_PERSON_ADDER_PATH
      }
    end
  end
end
