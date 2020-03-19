# frozen_string_literal: true

module VeteranVerification
  class ServiceHistorySerializer < ActiveModel::Serializer
    attributes :branch_of_service, :start_date, :end_date, :pay_grade_code,
               :discharge_status, :separation_reason, :deployments
    type 'service_history_episodes'
  end
end
