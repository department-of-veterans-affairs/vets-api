# frozen_string_literal: true

module CypressViewportUpdater
  class CypressJsonFile < ExistingGithubFile
    def initialize
      super(github_path: 'config/cypress.json', name: 'cypress.json')
    end

    def update(viewports:)
      hash = JSON.parse(raw_content)
      hash['viewportWidth'] = viewports.desktop[0].width
      hash['viewportHeight'] = viewports.desktop[0].height
      hash['env']['vaTopMobileViewports'] = viewports.mobile
      hash['env']['vaTopTabletViewports'] = viewports.tablet
      hash['env']['vaTopDesktopViewports'] = viewports.desktop
      self.updated_content = JSON.pretty_generate(JSON.parse(hash.to_json))
      self
    end
  end
end
