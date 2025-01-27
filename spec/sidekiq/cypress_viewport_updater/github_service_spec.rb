# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CypressViewportUpdater::GithubService do
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
    # stub methods in GithubService#new
    allow(OpenSSL::PKey::RSA).to receive(:new).and_return(true)
    allow(JWT).to receive(:encode).and_return(true)
    allow_any_instance_of(Octokit::Client).to receive(:create_installation_access_token).and_return([%w[k v]])
  end

  describe '#new' do
    it 'returns a new instance' do
      github = CypressViewportUpdater::GithubService.new
      expect(github).to be_an_instance_of(described_class)
    end
  end

  describe '#get_content' do
    let!(:file) { CypressViewportUpdater::CypressConfigJsFile.new }

    before do
      VCR.use_cassette('cypress_viewport_updater/github_service_get_content') do
        CypressViewportUpdater::GithubService.new.get_content(file:)
      end
    end

    it 'fetches the sha of the given file and assigns it to the sha attribute of the file' do
      expect(file.sha).to match(/\b[0-9a-f]{40}\b/)
    end

    it 'fetches the raw content of the given file and assign it to the raw_content attribute of the file' do
      expect(file.raw_content).to be_a(String)
    end
  end

  describe '#create_branch' do
    before do
      VCR.use_cassette('cypress_viewport_updater/github_service_create_branch') do
        @create_branch = CypressViewportUpdater::GithubService.new.create_branch
      end
    end

    it 'returns the sha the feature branch was was based off' do
      expect(@create_branch.object.sha).to match(/\b[0-9a-f]{40}\b/)
    end

    it 'returns the ref for the new feature branch' do
      expect(@create_branch.ref).to match(%r{refs/heads/\d+_update_cypress_viewport_data})
    end
  end

  describe '#update_content' do
    let!(:file) { CypressViewportUpdater::CypressConfigJsFile.new }

    before do
      github = nil

      VCR.use_cassette('cypress_viewport_updater/github_service_update_content_new') do
        github = CypressViewportUpdater::GithubService.new
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_update_content_get_content') do
        github.get_content(file:)
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_update_content_create_branch') do
        github.create_branch
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_update') do
        file.updated_content = 'Updated content'
        @update_content = github.update_content(file:)
      end
    end

    it 'returns the name of the file' do
      expect(@update_content.content.name).to eq(file.name)
    end

    it 'returns the github file path' do
      expect(@update_content.content.path).to eq(file.github_path)
    end
  end

  describe '#submit_pr' do
    before do
      file_1 = CypressViewportUpdater::CypressConfigJsFile.new
      file_2 = CypressViewportUpdater::ViewportPresetJsFile.new
      github = nil

      VCR.use_cassette('cypress_viewport_updater/github_service_submit_pr_new') do
        github = CypressViewportUpdater::GithubService.new
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_submit_pr_get_content_file_1') do
        github.get_content(file: file_1)
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_submit_pr_get_content_file_2') do
        github.get_content(file: file_2)
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_submit_pr_create_branch') do
        github.create_branch
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_submit_pr_update_content_file_1') do
        file_1.updated_content = 'File 1 content'
        github.update_content(file: file_1)
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_submit_pr_update_content_file_2') do
        file_2.updated_content = 'File 2 content'
        github.update_content(file: file_2)
      end

      VCR.use_cassette('cypress_viewport_updater/github_service_submit_pr') do
        @submit_pr = github.submit_pr
      end
    end

    it 'submits a pr to the department-of-veterans-affairs/vets-website repo' do
      expect(@submit_pr.base.repo.full_name).to eq('department-of-veterans-affairs/vets-website')
    end

    it 'returns the number of commits in the repo' do
      expect(@submit_pr.commits).to eq(2)
    end

    it 'returns the url to the pr' do
      expect(@submit_pr.url)
        .to match(%r{\bhttps://api.github.com/repos/department-of-veterans-affairs/vets-website/pulls/\d+\b})
    end

    it 'returns the pr title' do
      expect(@submit_pr.title).not_to eq('')
    end

    it 'returns the pr body' do
      expect(@submit_pr.body).not_to eq('')
    end
  end
end
