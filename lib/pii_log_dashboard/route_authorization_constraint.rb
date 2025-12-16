# frozen_string_literal: true

module PiiLogDashboard
  class RouteAuthorizationConstraint
    def self.matches?(request)
      # In development, allow access without GitHub auth (optional)
      return true if Rails.env.development? && Settings.pii_log_dashboard.github_oauth_key.blank?

      # If authenticated through GitHub, check authorization
      if request.session[:pii_log_dashboard_user].present?
        user = request.session[:pii_log_dashboard_user]
        RequestStore.store[:pii_log_dashboard_user] = user

        return authorized?(user)
      end

      # allow GET requests (minus oauth callbacks)
      return true if request.method == 'GET' && request.path.exclude?('/callback') &&
                     Settings.pii_log_dashboard.github_oauth_key.blank?

      authenticate(request)
      true
    end

    def self.authenticate(request)
      warden = request.env['warden']
      warden.authenticate!(scope: :pii_log_dashboard)
      request.session[:pii_log_dashboard_user] = warden.user
    end

    def self.authorized?(user)
      return true if Settings.pii_log_dashboard.github_oauth_key.blank?

      org_name = Settings.pii_log_dashboard.github_organization
      admin_team_id = Settings.pii_log_dashboard.admin_github_team

      # Must be in the organization
      return false unless user&.organization_member?(org_name)

      # Admin team can see everything
      return true if admin_team_id.present? && user.team_member?(admin_team_id)

      # Otherwise check if user is in any team that has access mappings
      team_access.any? { |_error_class_pattern, team_id| user.team_member?(team_id) }
    end

    # Returns the error_class patterns this user can access based on their team memberships
    def self.accessible_error_classes_for_user(user)
      return :all if Settings.pii_log_dashboard.github_oauth_key.blank?
      return :all if admin_access?(user)

      patterns = team_access.select { |_pattern, team_id| user.team_member?(team_id) }.keys
      patterns.presence || []
    end

    def self.admin_access?(user)
      admin_team_id = Settings.pii_log_dashboard.admin_github_team
      admin_team_id.present? && user&.team_member?(admin_team_id)
    end

    # Static mapping of error_class patterns to GitHub team IDs
    # This allows teams to only see PII logs for their own apps/controllers
    #
    # Pattern matching:
    #   - Exact match: 'ClaimsApi::VA526ez::V2' matches only that class
    #   - Prefix match with wildcard: 'ClaimsApi::*' matches all ClaimsApi classes
    #   - Regex patterns: '/^Lighthouse/' matches classes starting with Lighthouse
    #
    # Example configuration in settings.yml:
    #   pii_log_dashboard:
    #     team_access:
    #       - error_class_pattern: 'ClaimsApi::*'
    #         github_team: 12345678
    #       - error_class_pattern: 'MyHealth::*'
    #         github_team: 87654321
    #
    def self.team_access
      mappings = Settings.pii_log_dashboard.team_access || []
      mappings.each_with_object({}) do |mapping, hash|
        hash[mapping.error_class_pattern] = mapping.github_team
      end
    end

    # Check if an error_class matches any of the given patterns
    def self.error_class_matches_patterns?(error_class, patterns)
      return true if patterns == :all

      patterns.any? do |pattern|
        if pattern.start_with?('/') && pattern.end_with?('/')
          # Regex pattern
          regex = Regexp.new(pattern[1..-2])
          error_class.match?(regex)
        elsif pattern.end_with?('*')
          # Wildcard prefix match
          prefix = pattern.chomp('*')
          error_class.start_with?(prefix)
        else
          # Exact match
          error_class == pattern
        end
      end
    end
  end
end
