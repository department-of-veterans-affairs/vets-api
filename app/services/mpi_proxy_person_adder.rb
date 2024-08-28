# frozen_string_literal: true

# Service class for validating and creating a participant in MPI by ICN
# This class will propogate any error that occurs while being processed.
class MPIProxyPersonAdder
  attr_reader :user_account_uuid, :profile, :icn

  # Retrieve user profile from MPI on instantiation
  def initialize(icn)
    @icn = icn
    @user_account_uuid = UserAccount.find_by(icn:)&.id
    @mpi_service = MPI::Service.new
  end

  ##
  # Class method to retrieve MPI profile for icn,
  # validate if able to run add_person_proxy, and only call MPI's
  # add_person_proxy if all validation checks pass. If checks don't
  # pass, then skip the add_person_proxy call.
  #
  # @param icn
  #
  def self.add_person_proxy_by_icn(icn)
    new(icn).add_person_proxy_by_icn
  end

  ##
  # Instance method to retrieve MPI profile for icn,
  # validate if able to run add_person_proxy, and only call MPI's
  # add_person_proxy if all validation checks pass. If checks don't
  # pass, then skip the add_person_proxy call.
  #
  # @param icn
  #
  def add_person_proxy_by_icn
    track_proxy_add_begun

    fetch_profile

    if profile.present? && MPIPolicy.new(profile).access_add_person_proxy?
      @mpi_service.add_person_proxy(**add_person_proxy_params)
      track_proxy_add_success
      true
    else
      track_proxy_add_skipped
      false
    end
  rescue => e
    track_proxy_add_failure(e)
    raise e
  end

  private

  STATSD_KEY_PREFIX = 'mpi_proxy.add_person_proxy_by_icn'
  DEFAULT_LOGGER_MESSAGE = 'Add person proxy by icn'
  MPI_PROXY_PERSON_ADDER_PATH = 'app/services/mpi_proxy_person_adder'

  ##
  # Function to fetch MPI profile by user's ICN.
  # If response returns an error, propogates the returned error.
  def fetch_profile
    raise ArgumentError, 'Unable to fetch MPI profile. Missing ICN.' if icn.blank?

    response = @mpi_service.find_profile_by_identifier(
      identifier: icn,
      identifier_type: MPI::Constants::ICN
    )
    raise response.error if response.error.present?

    @profile = response.profile
  rescue MPI::Errors::RecordNotFound => e
    track_proxy_add_failure(e, 'No MPI profile found for given user account')
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

  def track_proxy_add_begun
    StatsD.increment("#{STATSD_KEY_PREFIX}.begun")
    context = {
      user_account_uuid:,
      source: MPI_PROXY_PERSON_ADDER_PATH
    }
    Rails.logger.info("#{DEFAULT_LOGGER_MESSAGE} begun", context)
  end

  def track_proxy_add_success
    StatsD.increment("#{STATSD_KEY_PREFIX}.success")
    context = {
      user_account_uuid:,
      source: MPI_PROXY_PERSON_ADDER_PATH
    }
    Rails.logger.info("#{DEFAULT_LOGGER_MESSAGE} succeeded", context)
  end

  def track_proxy_add_skipped(message = nil)
    StatsD.increment("#{STATSD_KEY_PREFIX}.skipped")
    context = {
      user_account_uuid:,
      source: MPI_PROXY_PERSON_ADDER_PATH
    }
    Rails.logger.info(message || "#{DEFAULT_LOGGER_MESSAGE} skipped", context)
  end

  def track_proxy_add_failure(error, message = nil)
    StatsD.increment("#{STATSD_KEY_PREFIX}.failure")
    context = {
      error:,
      user_account_uuid:,
      source: MPI_PROXY_PERSON_ADDER_PATH
    }
    Rails.logger.warn((message || "#{DEFAULT_LOGGER_MESSAGE} failed"), context)
  end
end
