# frozen_string_literal: true

module Admin
  class PersonalInformationLogsController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def index
      @logs = PersonalInformationLog.order(created_at: :desc)
      @logs = @logs.where(error_class: params[:error_class]) if params[:error_class].present?
      @logs = @logs.where('created_at >= ?', params[:from_date]) if params[:from_date].present?
      @logs = @logs.where('created_at <= ?', params[:to_date]) if params[:to_date].present?

      per_page = (params[:per_page] || 25).to_i
      @logs = @logs.paginate(page: params[:page], per_page:)
      @error_classes = PersonalInformationLog.distinct.pluck(:error_class).compact.sort

      render template: 'admin/personal_information_logs/index', layout: false
    end

    def show
      @log = PersonalInformationLog.find(params[:id])
      render template: 'admin/personal_information_logs/show', layout: false
    end

    def export
      logs = PersonalInformationLog.order(created_at: :desc)
      logs = logs.where(error_class: params[:error_class]) if params[:error_class].present?
      logs = logs.where('created_at >= ?', params[:from_date]) if params[:from_date].present?
      logs = logs.where('created_at <= ?', params[:to_date]) if params[:to_date].present?
      logs = logs.limit(10_000)

      csv_data = generate_csv(logs)

      send_data csv_data,
                filename: "personal_information_logs_#{Time.zone.now.to_i}.csv",
                type: 'text/csv',
                disposition: 'attachment'
    end

    private

    def generate_csv(logs)
      require 'csv'

      CSV.generate do |csv|
        csv << ['ID', 'Error Class', 'Created At', 'Data']

        logs.each do |log|
          csv << [
            log.id,
            log.error_class,
            log.created_at,
            log.data.to_json
          ]
        end
      end
    end
  end
end
