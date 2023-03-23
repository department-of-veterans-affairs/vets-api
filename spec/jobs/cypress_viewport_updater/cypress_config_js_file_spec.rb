# frozen_string_literal: true

require 'rails_helper'

LINES_TO_SKIP = %w[vaTopTabletViewportsIterateUptoIndex vaTopDesktopViewportsIterateUptoIndex].freeze
SPECIAL_CHARS = %w[\[ \] { }].freeze

RSpec.describe CypressViewportUpdater::CypressConfigJsFile do
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

      VCR.use_cassette('cypress_viewport_updater/github_get_cypress_config_js_file') do
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
      data = @file.update(viewports: @viewports).updated_content
      expect(data.scan('VA Top Mobile Viewports').count).to eq(required_number)
    end

    it 'creates the correct number of tablet viewport objects' do
      required_number = CypressViewportUpdater::Viewports::NUM_TOP_VIEWPORTS[:tablet]
      data = @file.update(viewports: @viewports).updated_content
      expect(data.scan('VA Top Tablet Viewports').count).to eq(required_number)
    end

    it 'creates the correct number of desktop viewport objects' do
      required_number = CypressViewportUpdater::Viewports::NUM_TOP_VIEWPORTS[:desktop]
      data = @file.update(viewports: @viewports).updated_content
      expect(data.scan('VA Top Desktop Viewports').count).to eq(required_number)
    end

    it 'creates mobile viewport objects with the correct data' do
      data = @file.update(viewports: @viewports).updated_content
      mobile_viewports = extract_viewport_data_from_javascript_file(data:)['vaTopMobileViewports']

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
      data = @file.update(viewports: @viewports).updated_content
      tablet_viewports = extract_viewport_data_from_javascript_file(data:)['vaTopTabletViewports']

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
      data = @file.update(viewports: @viewports).updated_content
      desktop_viewports = extract_viewport_data_from_javascript_file(data:)['vaTopDesktopViewports']

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

  def number?(line)
    line.match(/^-?[0-9]+\..?[0-9]+$/) || line.to_i.to_s == line
  end

  def special_char?(line)
    SPECIAL_CHARS.any? { |char| line.include?(char) }
  end

  def extract_viewport_data_from_javascript_file(data:)
    selected_lines = select_lines_from_file(data:)
    selected_lines = remove_chars(selected_lines:)
    JSON.parse("{#{format_as_json(selected_lines:).join}")
  end

  def select_lines_from_file(data:)
    select_lines = false

    data.split("\n").each_with_object([]) do |line, array|
      next if LINES_TO_SKIP.any? { |line_to_skip| line.include?(line_to_skip) }

      select_lines = true if line.include?('vaTopMobileViewports:')
      select_lines = false if line.include?('e2e: {')
      array << line.strip if select_lines
    end
  end

  def remove_chars(selected_lines:)
    selected_lines = selected_lines.map do |line|
      # only sub the first colon in a string (the one that follows the property name)
      line = line.sub(':', ':DELINEATOR') if line.include?(': ')
      # split on the first colon
      line = line.split(':DELINEATOR').map(&:strip) if line.include?('DELINEATOR')
      line
    end

    selected_lines.flatten.map do |line|
      line = line.gsub('"', '\"') if line.include?('"') # escape double quotes
      line = line.gsub("'", '') if line.include?("'") # remove single quotes
      line = line.gsub(',', '') if line.end_with?(',') # remove commas
      line
    end
  end

  # rubocop:disable Metrics/MethodLength
  def format_as_json(selected_lines:)
    in_object = false
    object_prop_index_is_even = nil
    object_prop_index_is_odd = nil

    selected_lines.each_with_index.map do |line, index|
      # set flags
      if line == '{'
        in_object = true
        object_prop_index_is_even = (index + 1).even?
        object_prop_index_is_odd = (index + 1).odd?
      end

      in_object = false if line == '}'

      # wrap strings in double quotes
      line = "\"#{line}\"" if !number?(line) && !special_char?(line)

      # append colon to properties/keys
      line += ':' if %w[\[ \] { }].none? { |char| line.include?(char) } &&
                     (selected_lines[index + 1] == '[' ||
                     selected_lines[index + 1] == '{' ||
                     in_object &&
                     object_prop_index_is_even && index.even? || object_prop_index_is_odd && index.odd?)

      # append comma where necessary (at the end of most values, etc.)
      line += ',' if line == ']' && selected_lines[index + 1] != '}' ||
                     line == '}' && selected_lines[index + 1] == '{' ||
                     (in_object &&
                     line.exclude?('{') &&
                     selected_lines[index + 1].exclude?('}') &&
                     selected_lines[index + 1].exclude?(']') &&
                     (object_prop_index_is_even && index.odd? || object_prop_index_is_odd && index.even?))

      line
    end
  end
  # rubocop:enable Metrics/MethodLength
end
