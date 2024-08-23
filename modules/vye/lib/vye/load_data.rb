# frozen_string_literal: true

module Vye
  class UserProfileConflict < RuntimeError; end
  class UserProfileNotFound < RuntimeError; end

  class LoadData
    SOURCES = %i[team_sensitive tims_feed bdn_feed].freeze

    private_constant :SOURCES

    private

    attr_reader :bdn_clone, :locator, :user_profile, :user_info, :source

    def initialize(source:, locator:, bdn_clone: nil, records: {})
      raise ArgumentError, format('Invalid source: %<source>s', source:) unless sources.include?(source)
      raise ArgumentError, 'Missing profile' if records[:profile].blank?
      raise ArgumentError, 'Missing bdn_clone' unless source == :tims_feed || bdn_clone.present?

      @bdn_clone = bdn_clone
      @locator = locator
      @source = source

      UserProfile.transaction do
        send(source, **records)
      end

      @valid_flag = true
    rescue => e
      @error_message =
        format(
          'Loading data failed: source: %<source>s, locator: %<locator>s, error message: %<message>s',
          source:, locator:, message: e.message
        )
      Rails.logger.error @error_message
      @valid_flag = false
    end

    def sources = SOURCES

    def team_sensitive(profile:, info:, address:, awards: [], pending_documents: [])
      load_profile(profile)
      load_info(info)
      load_address(address)
      load_awards(awards)
      load_pending_documents(pending_documents)
    end

    def tims_feed(profile:, pending_document:)
      load_profile(profile)
      load_pending_document(pending_document)
    end

    def bdn_feed(profile:, info:, address:, awards: [])
      bdn_clone_line = locator
      load_profile(profile)
      load_info(info.merge(bdn_clone_line:))
      load_address(address)
      load_awards(awards)
    end

    def load_profile(attributes)
      user_profile, conflict, attribute_name =
        UserProfile
        .produce(attributes)
        .values_at(:user_profile, :conflict, :attribute_name)

      if user_profile.new_record? && source == :tims_feed
        raise UserProfileNotFound
      elsif conflict == true && source == :tims_feed
        raise UserProfileConflict
      elsif conflict == true
        message =
          format(
            'Updated conflict for %<attribute_name>s from BDN feed line: %<locator>s',
            attribute_name:, locator:
          )
        Rails.logger.info message
      end

      user_profile.save!
      @user_profile = user_profile
    end

    def load_info(attributes)
      @user_info = user_profile.user_infos.create!(attributes.merge(bdn_clone:))
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

    attr_reader :error_message

    def valid?
      @valid_flag
    end
  end
end
