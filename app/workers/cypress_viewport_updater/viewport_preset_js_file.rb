# frozen_string_literal: true

module CypressViewportUpdater
  class ViewportPresetJsFile < ExistingGithubFile
    def initialize
      super(github_path: 'src/platform/testing/e2e/cypress/support/commands/viewportPreset.js',
            name: 'viewportPreset.js')
    end

    def update(viewports:)
      new_lines = []

      raw_content.split("\n").each do |line|
        if /va-top-(mobile|tablet|desktop)-\d+/.match(line)
          if /va-top-(mobile|tablet|desktop)-1/.match(line)
            create_viewport_presets(line:,
                                    viewports:) do |updated_line|
                                      new_lines << updated_line
                                    end
          end
        else
          new_lines << line
        end
      end

      self.updated_content = "#{new_lines.join("\n")}\n"
      self
    end

    private

    def create_viewport_presets(line:, viewports:)
      viewport_type = /(mobile|tablet|desktop)/.match(line)[0].to_sym

      viewports.send(viewport_type).each do |viewport|
        rank = viewport.rank
        width = viewport.width
        height = viewport.height
        yield("  'va-top-#{viewport_type}-#{rank}': { width: #{width}, height: #{height} },")
      end
    end
  end
end
