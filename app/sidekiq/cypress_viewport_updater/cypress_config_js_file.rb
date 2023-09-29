# frozen_string_literal: true

module CypressViewportUpdater
  class CypressConfigJsFile < ExistingGithubFile
    VIEWPORT_TYPES = {
      vaTopMobileViewports: 'mobile',
      vaTopTabletViewports: 'tablet',
      vaTopDesktopViewports: 'desktop'
    }.freeze
    VIEWPORT_PROPS = %w[
      rank:
      devicesWithViewport:
      percentTraffic:
      percentTrafficPeriod:
      viewportPreset:
      width:
      height:
    ].freeze
    WRAP_VALUE_IN_QUOTES = %w[list: devicesWithViewport: percentTraffic: percentTrafficPeriod: viewportPreset:].freeze

    def initialize
      super(github_path: 'config/cypress.config.js', name: 'cypress.config.js')
    end

    # rubocop:disable Metrics/MethodLength
    def update(viewports:)
      viewport_type = nil
      viewport_idx = nil
      skip_next_line = false
      lines = raw_content.split("\n")

      self.updated_content = "#{lines.each_with_object([]).with_index do |(line, new_lines), idx|
        if skip_next_line
          skip_next_line = false
          next
        end

        if (type = VIEWPORT_TYPES.keys.select { |t| line.include?(t.to_s) }.first)
          viewport_type = VIEWPORT_TYPES[type]
          viewport_idx = 0
        end

        new_line = if line.include?('viewportWidth:')
                     rewrite_line(line:, new_value: viewports.desktop[0].width, prop: 'viewportWidth')
                   elsif line.include?('viewportHeight:')
                     rewrite_line(line:, new_value: viewports.desktop[0].height, prop: 'viewportHeight')
                   elsif (prop = VIEWPORT_PROPS.select { |p| line.include?(p.to_s) }.first)
                     viewport_idx += 1 if prop == 'height:'
                     if prop == 'devicesWithViewport:' && lines[idx + 1].exclude?('percentTraffic:')
                       skip_next_line = true
                     end
                     rewrite_line(line:,
                                  new_value: viewports
                                               .send(viewport_type)[prop == 'height:' ? viewport_idx - 1 : viewport_idx]
                                               .send(prop.chomp(':')),
                                  prop:)
                   end

        new_lines.push(new_line.nil? ? line : new_line)
      end.flatten.join("\n")}\n"

      self
    end
    # rubocop:enable Metrics/MethodLength

    private

    def rewrite_line(line:, new_value:, prop:)
      line_parts = line.split(':')

      new_line = if WRAP_VALUE_IN_QUOTES.include?(prop)
                   line_parts[0] + ": '#{new_value}',"
                 else
                   line_parts[0] + ": #{new_value},"
                 end

      if new_line.length > 80
        return [
          "#{line_parts[0]}:",
          "#{line_parts[0].match(/^\s+/)[0]}  #{new_line.split(': ')[1]}"
        ]
      end

      new_line
    end
  end
end
