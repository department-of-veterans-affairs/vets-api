# frozen_string_literal: true

module Vye
  class LoadData
    SOURCES = %i[team_sensitive tims_feed bdn_feed].freeze

    private_constant :SOURCES

    attr_reader :profile

    def initialize(source:, records: {})
      raise ArgumentError, format('Invalid source: %<source>s', { source: }) unless sources.include?(source)
      raise ArgumentError, 'Missing profile' if records[:profile].blank?

      send(source, **records)
      profile.save!
    end

    private

    attr_accessor :info
    attr_writer :profile

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
      load_profile(profile)
      load_info(info)
      load_address(address)
      load_awards(awards)
    end

    def load_profile(attributes)
      self.profile = UserProfile.produce(attributes)
    end

    def load_info(attributes)
      self.info = profile.user_infos.build(attributes)
    end

    def load_address(attributes)
      info.address_changes.build(attributes)
    end

    def load_awards(awards)
      awards.each do |attributes|
        info.awards.build(attributes)
      end
    end

    def load_pending_document(attributes)
      profile.pending_documents.build(attributes)
    end

    def load_pending_documents(pending_documents)
      pending_documents.each do |attributes|
        profile.pending_documents.build(attributes)
      end
    end
  end
end
