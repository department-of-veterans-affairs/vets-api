# frozen_string_literal: true

module CypressViewportUpdater
  class UpdateCypressViewportsJob
    include Sidekiq::Worker

    START_DATE = Time.zone.today.prev_month.beginning_of_month
    END_DATE = Time.zone.today.prev_month.end_of_month

    def perform
      analytics = CypressViewportUpdater::GoogleAnalyticsReports
                  .new
                  .request_reports

      viewports = CypressViewportUpdater::Viewports
                  .new(user_report: analytics.user_report)
                  .create(viewport_report: analytics.viewport_report)

      github = CypressViewportUpdater::GithubService.new
      cypress_json_file = CypressViewportUpdater::CypressJsonFile.new
      viewport_preset_js_file = CypressViewportUpdater::ViewportPresetJsFile.new
      github.get_content(file: cypress_json_file)
      github.get_content(file: viewport_preset_js_file)
      github.create_branch

      [cypress_json_file, viewport_preset_js_file].each do |file|
        file.update(viewports: viewports)
        github.update_content(file: file)
      end

      github.submit_pr
      self
    end
  end
end
