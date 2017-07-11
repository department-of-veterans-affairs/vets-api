# frozen_string_literal: true
require 'common/client/base'

module Preneeds
  class Service < Common::Client::Base
    configuration Preneeds::Configuration

    def get_attachment_types
      json = hit_cache(:attachment_types, :get_attachment_types)
      Common::Collection.new(AttachmentType, data: json['data'])
    end

    def get_branches_of_service
      json = hit_cache(:branches_of_service, :get_branches_of_service)
      Common::Collection.new(BranchesOfService, data: json['data'])
    end

    def get_cemeteries
      json = hit_cache(:cemeteries, :get_cemeteries)
      Common::Collection.new(Cemetery, data: json['data'])
    end

    def get_discharge_types
      json = hit_cache(:discharge_types, :get_discharge_types)
      Common::Collection.new(DischargeType, data: json['data'])
    end

    def get_military_rank_for_branch_of_service(params)
      key = "military_ranks_#{params.values.join('_')}".underscore.to_sym
      json = hit_cache(key, :get_military_rank_for_branch_of_service, params)
      Common::Collection.new(MilitaryRank, data: json['data'])
    end

    def get_states
      json = hit_cache(:states, :get_states)
      Common::Collection.new(State, data: json['data'])
    end

    def receive_pre_need_application(params)
      tracking_number = params[:tracking_number]
      message = { pre_need_request: params }

      soap = savon_client.build_request(:receive_pre_need_application, message: message)
      json = perform(:post, '', soap.body).body
      json = json[:data].merge('tracking_number' => tracking_number)

      ReceiveApplication.new(json)
    end

    private

    def hit_cache(key, method, params = {})
      if expired?(key)
        soap = savon_client.build_request(method, message: params)
        data = perform(:post, '', soap.body).body

        Redis.current.set(key, data.to_json)
        Redis.current.expire(key, Preneeds::Configuration::REDIS_EACH_TTL)
      end

      JSON.parse(Redis.current.get(key) || '{}')
    end

    def expired?(key)
      Redis.current.ttl(key) < -1
    end

    def savon_client
      @savon ||= Savon.client(wsdl: Settings.preneeds.wsdl)
    end
  end
end
