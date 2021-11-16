# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CypressViewportUpdater::CypressJsonFile do
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
    string = '{"token":"removed","expires_at":"2021-02-02T18:24:37Z",'\
             '"permissions":{"contents":"write","metadata":"read","pull_requests":"write"},'\
             '"repository_selection":"selected"}'
    c.filter_sensitive_data(string) do |interaction|
      if (match = interaction.response.body.match(/^{"token.+/))
        match[0]
      end
    end
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

      @file = described_class.new

      google = VCR.use_cassette('cypress_viewport_updater/google_analytics_after_request_report') do
        CypressViewportUpdater::GoogleAnalyticsReports
          .new
          .request_reports
      end

      @viewports = CypressViewportUpdater::Viewports
                   .new(user_report: google.user_report)
                   .create(viewport_report: google.viewport_report)

      VCR.use_cassette('cypress_viewport_updater/github_get_cypress_json_file') do
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

    it 'creates the correct number of mobile viewport objects' do
      required_number = CypressViewportUpdater::Viewports::NUM_TOP_VIEWPORTS[:mobile]
      data = JSON.parse(@file.update(viewports: @viewports).updated_content)
      actual_number = data['env']['vaTopMobileViewports'].count
      expect(required_number).to eq(actual_number)
    end

    it 'creates the correct number of tablet viewport objects' do
      required_number = CypressViewportUpdater::Viewports::NUM_TOP_VIEWPORTS[:tablet]
      data = JSON.parse(@file.update(viewports: @viewports).updated_content)
      actual_number = data['env']['vaTopTabletViewports'].count
      expect(required_number).to eq(actual_number)
    end

    it 'creates the correct number of desktop viewport objects' do
      required_number = CypressViewportUpdater::Viewports::NUM_TOP_VIEWPORTS[:desktop]
      data = JSON.parse(@file.update(viewports: @viewports).updated_content)
      actual_number = data['env']['vaTopDesktopViewports'].count
      expect(required_number).to eq(actual_number)
    end

    it 'creates mobile viewport objects with the correct data' do
      data = JSON.parse(@file.update(viewports: @viewports).updated_content)
      mobile_viewports = data['env']['vaTopMobileViewports']

      if @viewports.mobile.count == mobile_viewports.count
        @viewports.mobile.each_with_index do |new_data, i|
          data_in_file = mobile_viewports[i]
          expect(new_data.viewportPreset).to eq(data_in_file['viewportPreset'])
          expect(new_data.rank).to eq(data_in_file['rank'])
          expect(new_data.width).to eq(data_in_file['width'])
          expect(new_data.height).to eq(data_in_file['height'])
        end
      else
        # fail the test
        expect(@viewports.mobile.count).to eq(mobile_viewports.count)
      end
    end

    it 'creates tablet viewport objects with the correct data' do
      data = JSON.parse(@file.update(viewports: @viewports).updated_content)
      tablet_viewports = data['env']['vaTopTabletViewports']

      if @viewports.tablet.count == tablet_viewports.count
        @viewports.tablet.each_with_index do |new_data, i|
          data_in_file = tablet_viewports[i]
          expect(new_data.viewportPreset).to eq(data_in_file['viewportPreset'])
          expect(new_data.rank).to eq(data_in_file['rank'])
          expect(new_data.width).to eq(data_in_file['width'])
          expect(new_data.height).to eq(data_in_file['height'])
        end
      else
        # fail the test
        expect(@viewports.tablet.count).to eq(tablet_viewports.count)
      end
    end

    it 'creates desktop viewport objects with the correct data' do
      data = JSON.parse(@file.update(viewports: @viewports).updated_content)
      desktop_viewports = data['env']['vaTopDesktopViewports']

      if @viewports.desktop.count == desktop_viewports.count
        @viewports.desktop.each_with_index do |new_data, i|
          data_in_file = desktop_viewports[i]
          expect(new_data.viewportPreset).to eq(data_in_file['viewportPreset'])
          expect(new_data.rank).to eq(data_in_file['rank'])
          expect(new_data.width).to eq(data_in_file['width'])
          expect(new_data.height).to eq(data_in_file['height'])
        end
      else
        # fail the test
        expect(@viewports.desktop.count).to eq(desktop_viewports.count)
      end
    end
  end
end
