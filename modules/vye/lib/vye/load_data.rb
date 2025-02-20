# frozen_string_literal: true

module Vye
  class LoadData
    STATSD_PREFIX = name.gsub('::', '.').underscore
    STATSD_NAMES = {
      failure: "#{STATSD_PREFIX}.failure.no_source",
      team_sensitive_failure: "#{STATSD_PREFIX}.failure.team_sensitive",
      tims_feed_failure: "#{STATSD_PREFIX}.failure.tims_feed",
      bdn_feed_failure: "#{STATSD_PREFIX}.failure.bdn_feed",
      user_profile_created: "#{STATSD_PREFIX}.user_profile.created",
      user_profile_updated: "#{STATSD_PREFIX}.user_profile.updated",
      user_profile_creation_skipped: "#{STATSD_PREFIX}.user_profile.creation_skipped",
      user_profile_update_skipped: "#{STATSD_PREFIX}.user_profile.update_skipped"
    }.freeze

    SOURCES = %i[team_sensitive tims_feed bdn_feed].freeze

    FAILURE_TEMPLATE = <<~FAILURE_TEMPLATE_HEREDOC.gsub(/\n/, ' ').freeze
      Loading data failed:
      source: %<source>s,
      locator: %<locator>s,
      error message: %<error_message>s
    FAILURE_TEMPLATE_HEREDOC

    private_constant :SOURCES

    private

    attr_reader :bdn_clone, :locator, :user_profile, :user_info, :source

    def initialize(source:, locator:, bdn_clone: nil, records: {})
      raise ArgumentError, format('Invalid source: %<source>s', source:) unless sources.include?(source)
      raise ArgumentError, 'Missing locater' if locator.blank?
      raise ArgumentError, 'Missing bdn_clone' unless source == :tims_feed || bdn_clone.present?

      @bdn_clone = bdn_clone
      @locator = locator
      @source = source

      UserProfile.transaction do
        @valid_flag = send(source, **records)
      end
    rescue => e
      format(FAILURE_TEMPLATE, source:, locator:, error_message: e.message).tap do |msg|
        Rails.logger.error(msg)
      end

      (sources.include?(source) ? :"#{source}_failure" : :failure).tap do |key|
        StatsD.increment(STATSD_NAMES[key])
      end

      Sentry.capture_exception(e)
      @valid_flag = false
    end

    def sources = SOURCES

    def team_sensitive(profile:, info:, address:, awards: [], pending_documents: [])
      return false unless load_profile(profile)

      load_info(info)
      load_address(address)
      load_awards(awards)
      load_pending_documents(pending_documents)
      true
    end

    def tims_feed(profile:, pending_document:)
      return false unless load_profile(profile)

      load_pending_document(pending_document)
      true
    end

    def bdn_feed(profile:, info:, address:, awards: [])
      return false unless load_profile(profile)

      load_info(info)
      load_address(address)
      load_awards(awards)
      true
    end

    def load_profile(attributes)
      attributes || {} => {ssn:, file_number:} # this shouldn't throw NoMatchingPatternKeyError
      user_profile = UserProfile.produce(attributes)

      unless user_profile.new_record? || user_profile.changed?
        # as time goes on this should be whats mostly happening
        @user_profile = user_profile
        return true
      end

      if source == :tims_feed && user_profile.new_record?
        # we are not going to create a new record based of off the TIMS feed
        StatsD.increment(STATSD_NAMES[:user_profile_creation_skipped])
        return false
      end

      if source == :tims_feed && user_profile.changed?
        # we are not updating a record conflict from TIMS
        StatsD.increment(STATSD_NAMES[:user_profile_update_skipped])
        return false
      end

      if user_profile.new_record?
        # we are going to count the number of records created
        # this should be decreasing over time
        StatsD.increment(STATSD_NAMES[:user_profile_created])
        user_profile.save!
        @user_profile = user_profile
        return true
      end

      if user_profile.changed?
        # this shouldn't be happening
        # we will update a record conflict from BDN (or TeamSensitive),
        # but need to investigate why this is happening
        user_profile_id = user_profile.id
        changed_attributes = user_profile.changed_attributes

        format(
          'UserProfile(%<user_profile_id>u) updated %<changed_attributes>p from BDN feed line: %<locator>s',
          user_profile_id:, changed_attributes:, locator:
        ).tap do |msg|
          Rails.logger.warn msg
        end

        StatsD.increment(STATSD_NAMES[:user_profile_updated])
        user_profile.save!
        @user_profile = user_profile
        true
      end
    end

    def load_info(attributes)
      bdn_clone_line = locator
      attributes_final = attributes.merge(bdn_clone:, bdn_clone_line:)
      @user_info = user_profile.user_infos.create!(attributes_final)
    end

    def load_address(attributes)
      user_info.address_changes.create!(attributes)
    end

    def load_awards(awards)
      awards&.each do |attributes|
        user_info.awards.create!(attributes)
      end
    end

    def load_pending_document(attributes)
      user_profile.pending_documents.create!(attributes)
    end

    def load_pending_documents(pending_documents)
      pending_documents.each do |attributes|
        user_profile.pending_documents.create!(attributes)
      end
    end

    public

    def valid?
      @valid_flag
    end
  end
end
