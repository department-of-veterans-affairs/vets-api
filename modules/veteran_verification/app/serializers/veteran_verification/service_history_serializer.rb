# frozen_string_literal: true

module VeteranVerification
  class ServiceHistorySerializer < ActiveModel::Serializer
    attributes :branch_of_service, :start_date, :end_date, :discharge_status, :deployments
    type 'service_history_episodes'
  end
end
