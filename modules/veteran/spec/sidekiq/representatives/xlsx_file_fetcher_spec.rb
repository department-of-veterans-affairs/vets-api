# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Representatives::XlsxFileFetcher do
  describe '#fetch' do
    let(:octokit_client) { instance_double(Octokit::Client) }
    let(:github_access_token) { 'test_token' }
    let(:file_info) { double('Sawyer::Resource', content: Base64.encode64('file content'), download_url: 'http://example.com/file.xlsx') }
    let(:commits) { [double('commit', commit: double('commit data', author: double('author', date: 1.hour.ago)))] }
    let(:fetcher) { described_class.new }

    before do
      allow(fetcher).to receive(:fetch_github_access_token).and_return(github_access_token)
      allow(fetcher).to receive(:log_message_to_sentry)
      allow(Octokit::Client).to receive(:new).and_return(octokit_client)
      allow(octokit_client).to receive_messages(commits:, contents: file_info)
      allow(Net::HTTP).to receive(:get_response).and_return(instance_double(Net::HTTPSuccess, body: 'file content',
                                                                                              is_a?: true))
    end

    context 'when fetching file successfully and it is recently updated' do
      it 'returns the content of the file' do
        expect(fetcher.fetch).to eq('file content')
      end
    end

    context 'when an error occurs during fetching file info' do
      it 'handles the error and returns nil' do
        allow(octokit_client).to receive(:contents).and_raise(StandardError.new('test error'))

        expect { fetcher.fetch }.not_to raise_error
        expect(fetcher.fetch).to be_nil
      end
    end

    context 'when the file has not been updated in the last 24 hours' do
      let(:old_commits) do
        [double('commit', commit: double('commit data', author: double('author', date: 25.hours.ago)))]
      end

      it 'returns nil' do
        allow(octokit_client).to receive(:commits).and_return(old_commits)

        expect(fetcher.fetch).to be_nil
      end
    end
  end
end
