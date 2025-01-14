# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CypressViewportUpdater::ViewportPresetJsFile do
  VCR.configure do |c|
    # the following filter is used on requests to
    # https://analyticsreporting.googleapis.com/v4/reports:batchGet
    # and all requests to https://api.github.com
    c.filter_sensitive_data('removed') do |interaction|
      if interaction.request.headers['Authorization']
        token = interaction.request.headers['Authorization'].first

        if (match = token.match(/^Bearer.+/) || token.match(/^token.+/))
          match[0]
        end
      end
    end

    # # the following filters are used on requests/responses to
    # # https://www.googleapis.com/oauth2/v4/token
    # c.filter_sensitive_data('removed') do |interaction|
    #   if (match = interaction.request.body.match(/^grant_type.+/))
    #     match[0]
    #   end
    # end

    c.filter_sensitive_data('{"access_token":"removed","expires_in":3599,"token_type":"Bearer"}') do |interaction|
      if (match = interaction.response.body.match(/^{"access_token.+/))
        match[0]
      end
    end

    # the following filter is used on responses from
    # https://api.github.com/app/installations/14176090/access_tokens
    string = '{"token":"removed","expires_at":"2021-02-02T18:24:37Z",' \
             '"permissions":{"contents":"write","metadata":"read","pull_requests":"write"},' \
             '"repository_selection":"selected"}'
    c.filter_sensitive_data(string) do |interaction|
      if (match = interaction.response.body.match(/^{"token.+/))
        match[0]
      end
    end
  end

  before do
    @file = described_class.new
  end

  it { expect(described_class).to be < CypressViewportUpdater::ExistingGithubFile }

  describe '#update' do
    before do
      # stub method in GoogleAnalyticsReports#new
      allow(Google::Auth::ServiceAccountCredentials).to receive(:make_creds).and_return(true)

      # stub methods in GithubService#new
      allow(OpenSSL::PKey::RSA).to receive(:new).and_return(true)
      allow(JWT).to receive(:encode).and_return(true)
      allow_any_instance_of(Octokit::Client).to receive(:create_installation_access_token).and_return([%w[k v]])

      google = VCR.use_cassette('cypress_viewport_updater/google_analytics_after_request_report') do
        CypressViewportUpdater::GoogleAnalyticsReports
          .new
          .request_reports
      end

      @viewports = CypressViewportUpdater::Viewports
                   .new(user_report: google.user_report)
                   .create(viewport_report: google.viewport_report)

      VCR.use_cassette('cypress_viewport_updater/github_get_viewport_preset_js_file') do
        CypressViewportUpdater::GithubService
          .new
          .get_content(file: @file)
      end
    end

    it 'returns self' do
      object_id_before = @file.object_id
      object_id_after = @file.update(viewports: @viewports).object_id
      expect(object_id_before).to eq(object_id_after)
    end

    it 'saves the updated data to updated_content' do
      expect(@file.updated_content).to be_nil
      @file.update(viewports: @viewports)
      expect(@file.updated_content).not_to be_nil
    end

    it 'creates presets with the correct data' do
      lines = @file.update(viewports: @viewports).updated_content.split("\n")

      lines.each_with_index do |line, line_index|
        if /va-top-(mobile|tablet|desktop)-1/.match(line)
          vp_type = /(mobile|tablet|desktop)/.match(line)[0].to_sym
          vp_data = @viewports.send(vp_type)
          vp_count = vp_data.count
          vp_data_index = 0
          line_index.upto(line_index + vp_count - 1) do |vp_type_line_index|
            vp = vp_data[vp_data_index]
            preset = "  'va-top-#{vp_type}-#{vp.rank}': { width: #{vp.width}, height: #{vp.height} },"
            expect(lines[vp_type_line_index]).to eq(preset)
            vp_data_index += 1
          end
        end
      end
    end
  end
end
