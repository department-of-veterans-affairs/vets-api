# frozen_string_literal: true

module Admin
  # Inherits from ActionController::Base intentionally to avoid vets-api session/auth
  # This controller uses GitHub OAuth via Warden for authentication
  class PersonalInformationLogsController < ActionController::Base # rubocop:disable Rails/ApplicationController
    include ActionController::Cookies

    before_action :authenticate_user!
    before_action :set_current_user

    skip_before_action :verify_authenticity_token

    def index
      @logs = filtered_logs.order(created_at: :desc)
      @logs = @logs.where(error_class: params[:error_class]) if params[:error_class].present?
      @logs = @logs.where('created_at >= ?', params[:from_date]) if params[:from_date].present?
      @logs = @logs.where('created_at <= ?', params[:to_date]) if params[:to_date].present?

      per_page = (params[:per_page] || 25).to_i
      @logs = @logs.paginate(page: params[:page], per_page:)
      @error_classes = accessible_error_classes

      render template: 'admin/personal_information_logs/index', layout: false
    end

    def show
      @log = filtered_logs.find(params[:id])
      render template: 'admin/personal_information_logs/show', layout: false
    rescue ActiveRecord::RecordNotFound
      render plain: 'Not found or access denied', status: :not_found
    end

    def export
      logs = filtered_logs.order(created_at: :desc)
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

    def login
      if github_auth_configured?
        warden.authenticate!(scope: :pii_log_dashboard)
        session[:pii_log_dashboard_user] = warden.user
      end
      redirect_to admin_personal_information_logs_path
    end

    def logout
      session.delete(:pii_log_dashboard_user)
      redirect_to admin_personal_information_logs_path
    end

    def auth_callback
      if params['error']
        render plain: 'Authentication failed', status: :forbidden
      else
        warden.authenticate!(scope: :pii_log_dashboard)
        session[:pii_log_dashboard_user] = warden.user
        redirect_to admin_personal_information_logs_path
      end
    end

    private

    def authenticate_user!
      return true unless github_auth_configured?

      @current_github_user = session[:pii_log_dashboard_user]

      if @current_github_user.blank?
        warden.authenticate!(scope: :pii_log_dashboard)
        session[:pii_log_dashboard_user] = warden.user
        @current_github_user = warden.user
      end

      return if authorized?(@current_github_user)

      render plain: 'Access denied. You are not a member of an authorized team.', status: :forbidden
    end

    def set_current_user
      @current_github_user ||= session[:pii_log_dashboard_user]
      @is_admin = admin_access?(@current_github_user)
      @accessible_patterns = accessible_patterns_for_user
    end

    def warden
      request.env['warden']
    end

    def github_auth_configured?
      Settings.pii_log_dashboard&.github_oauth_key.present?
    end

    def authorized?(user)
      return true unless github_auth_configured?

      org_name = Settings.pii_log_dashboard.github_organization
      return false unless user&.organization_member?(org_name)

      # Admin team can see everything
      return true if admin_access?(user)

      # Check if user is in any team that has access mappings
      team_access.any? { |_error_class_pattern, team_id| user.team_member?(team_id) }
    end

    def admin_access?(user)
      return true unless github_auth_configured?

      admin_team_id = Settings.pii_log_dashboard.admin_github_team
      admin_team_id.present? && user&.team_member?(admin_team_id)
    end

    # Returns the error_class patterns this user can access
    def accessible_patterns_for_user
      return :all unless github_auth_configured?
      return :all if admin_access?(@current_github_user)

      patterns = team_access.select do |_pattern, team_id|
        @current_github_user&.team_member?(team_id)
      end.keys
      patterns.presence || []
    end

    # Filter logs to only show those the user has access to
    def filtered_logs
      patterns = accessible_patterns_for_user
      return PersonalInformationLog.all if patterns == :all
      return PersonalInformationLog.none if patterns.empty?

      # Build a query that matches any of the patterns
      conditions = patterns.map { |pattern| pattern_to_sql_condition(pattern) }
      PersonalInformationLog.where(conditions.join(' OR '))
    end

    # Get error classes the user can see (for the dropdown filter)
    def accessible_error_classes
      filtered_logs.distinct.pluck(:error_class).compact.sort
    end

    # Convert pattern to SQL condition
    def pattern_to_sql_condition(pattern)
      if pattern.start_with?('/') && pattern.end_with?('/')
        # Regex pattern - use SIMILAR TO for PostgreSQL
        regex = pattern[1..-2]
        "error_class ~ '#{ActiveRecord::Base.connection.quote_string(regex)}'"
      elsif pattern.end_with?('*')
        # Wildcard prefix match
        prefix = pattern.chomp('*')
        "error_class LIKE '#{ActiveRecord::Base.connection.quote_string(prefix)}%'"
      else
        # Exact match
        "error_class = '#{ActiveRecord::Base.connection.quote_string(pattern)}'"
      end
    end

    def team_access
      @team_access ||= begin
        mappings = Settings.pii_log_dashboard&.team_access || []
        mappings.each_with_object({}) do |mapping, hash|
          hash[mapping.error_class_pattern] = mapping.github_team
        end
      end
    end

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
