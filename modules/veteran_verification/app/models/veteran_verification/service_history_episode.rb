# frozen_string_literal: true

require 'active_support/core_ext/digest/uuid'
require 'common/exceptions'

module VeteranVerification
  class ServiceHistoryEpisode
    include ActiveModel::Serialization
    include Virtus.model

    attribute :id, String
    attribute :first_name, String
    attribute :last_name, String
    attribute :branch_of_service, String
    attribute :end_date, Date
    attribute :deployments, Array
    attribute :discharge_type, String
    attribute :start_date, Date
    attribute :pay_grade, String
    attribute :separation_reason, String

    def self.emis_service
      Rails.logger.info("Settings.vet_verification.mock_emis: #{Settings.vet_verification.mock_emis}")
      if Settings.vet_verification.mock_emis == true
        EMISRedis::MockMilitaryInformationV2
      else
        EMISRedis::MilitaryInformationV2
      end
    end

    def self.for_user(user)
      emis = emis_service.for_user(user)
      handle_errors!(emis)
      episodes(emis, user)
    end

    def self.handle_errors!(emis)
      raise_error! unless emis.service_history.is_a?(Array)
    end

    def self.raise_error!
      raise Common::Exceptions::BackendServiceException.new(
        'EMIS_HIST502',
        source: self.class.to_s
      )
    end

    def self.episodes(emis, user)
      episodes = emis.service_episodes_by_begin_date.reverse
      deployments = emis.deployments.sort_by { |ep| ep.begin_date || Time.zone.today + 3650 }.reverse
      episodes.map do |episode|
        deployments_for_episode, deployments = deployments.partition do |dep|
          (dep.begin_date >= episode.begin_date) && (episode.end_date.nil? || dep.end_date <= episode.end_date)
        end
        ServiceHistoryEpisode.new(
          id: episode_identifier(episode, user),
          first_name: user.first_name,
          last_name: user.last_name,
          branch_of_service: emis.build_service_branch(episode),
          end_date: episode.end_date,
          deployments: deployments(deployments_for_episode),
          discharge_type: episode.discharge_character_of_service_code,
          start_date: episode.begin_date,
          pay_grade: build_pay_grade(episode),
          separation_reason: episode.narrative_reason_for_separation_txt
        )
      end
    end

    def self.episode_identifier(episode, user)
      Digest::UUID.uuid_v5(
        'gov.vets.service-history-episodes',
        "#{user.uuid}-#{episode.begin_date}-#{episode.end_date}"
      )
    end

    def self.deployments(deployments_for_episode)
      deployments_for_episode.map do |dep|
        {
          start_date: dep.begin_date,
          end_date: dep.end_date,
          location: dep.locations[0].iso_alpha3_country
        }
      end
    end

    def discharge_status
      EMISRedis::MilitaryInformationV2::EXTERNAL_DISCHARGE_TYPES[discharge_type] || 'unknown'
    end

    def self.build_pay_grade(episode)
      if episode.pay_plan_code.blank? || episode.pay_grade_code.blank?
        'unknown'
      else
        episode.pay_plan_code[1] + episode.pay_grade_code
      end
    end
  end
end
