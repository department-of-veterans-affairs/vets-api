# frozen_string_literal: true

require 'rails_helper'

RSpec.shared_examples 'an existing file' do
  describe '#github_path' do
    it 'returns the correct value' do
      expect(@file.github_path).to eq(github_path)
    end
  end

  describe '#name' do
    it 'returns the correct value' do
      expect(@file.name).to eq(name)
    end
  end

  describe '#sha' do
    it 'returns the correct value' do
      sha = '16C79BBE876272C7C47DB5C3E63FA220B4BC02CF'
      @file.sha = sha
      expect(@file.sha).to eq(sha)
    end
  end

  describe '#sha=' do
    it 'returns the correct value when it is updated' do
      sha_1 = '16C79BBE876272C7C47DB5C3E63FA220B4BC02CF'
      @file.sha = sha_1
      expect(@file.sha).to eq(sha_1)

      sha_2 = '72A707E23BF1EAC3BD7ABFF9C7CB26897ECB12F1'
      @file.sha = sha_2
      expect(@file.sha).to eq(sha_2)
    end
  end

  describe '#raw_content' do
    it 'returns the correct value' do
      raw_content = 'Some raw content'
      @file.raw_content = raw_content
      expect(@file.raw_content).to eq(raw_content)
    end
  end

  describe '#raw_content=' do
    it 'returns the correct value when it is updated' do
      raw_content_1 = 'Some raw content'
      @file.raw_content = raw_content_1
      expect(@file.raw_content).to eq(raw_content_1)

      raw_content_2 = 'Some different raw content'
      @file.raw_content = raw_content_2
      expect(@file.raw_content).to eq(raw_content_2)
    end
  end

  describe '#updated_content' do
    it 'returns the correct value' do
      updated_content = 'Content'
      @file.updated_content = updated_content
      expect(@file.updated_content).to eq(updated_content)
    end
  end

  describe '#updated_content=' do
    it 'returns the correct value when it is updated' do
      updated_content_1 = 'Content'
      @file.updated_content = updated_content_1
      expect(@file.updated_content).to eq(updated_content_1)

      updated_content_2 = 'Updated content'
      @file.updated_content = updated_content_2
      expect(@file.updated_content).to eq(updated_content_2)
    end
  end
end

context CypressViewportUpdater::ExistingGithubFile do
  let!(:github_path) { 'config/cypress.config.js' }
  let!(:name) { 'cypress.config.js' }

  before do
    @file = described_class.new(github_path:, name:)
  end

  it_behaves_like 'an existing file'
end

context CypressViewportUpdater::CypressConfigJsFile do
  let!(:github_path) { 'config/cypress.config.js' }
  let!(:name) { 'cypress.config.js' }

  before do
    @file = described_class.new
  end

  it_behaves_like 'an existing file'
end

context CypressViewportUpdater::ViewportPresetJsFile do
  let!(:github_path) { 'src/platform/testing/e2e/cypress/support/commands/viewportPreset.js' }
  let!(:name) { 'viewportPreset.js' }

  before do
    @file = described_class.new
  end

  it_behaves_like 'an existing file'
end
