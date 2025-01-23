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

    def update(viewports:)
      lines = raw_content.split("\n")
      self.updated_content = "#{process_lines(lines, viewports)}\n"
      self
    end

    private

    def process_lines(lines, viewports)
      viewport_type, viewport_idx = nil
      skip_next_line = false

      lines.each_with_object([]).with_index do |(line, new_lines), idx|
        next if skip_next_line.tap { skip_next_line = false }

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
                     skip_next_line = true if prop_with_viewport(prop) && line_excludes_traffic(lines, idx)
                     viewport_prop_new_line(viewports, line, prop, viewport_type, viewport_idx)
                   end
        new_lines.push(new_line.nil? ? line : new_line)
      end.flatten.join("\n")
    end

    def viewport_prop_new_line(viewports, line, prop, viewport_type, viewport_idx)
      viewport_type_index = prop == 'height:' ? viewport_idx - 1 : viewport_idx
      new_value = viewports.send(viewport_type)[viewport_type_index].send(prop.chomp(':'))
      rewrite_line(line:, new_value:, prop:)
    end

    def rewrite_line(line:, new_value:, prop:)
      line_prefix = line.split(':')[0]
      wrapped_value = WRAP_VALUE_IN_QUOTES.include?(prop) ? "'#{new_value}'" : new_value.to_s
      new_line = "#{line_prefix}: #{wrapped_value},"

      return new_line if new_line.length <= 80

      [
        "#{line_prefix}:",
        "#{line_prefix.match(/^\s+/)[0]}  #{wrapped_value},"
      ]
    end

    def prop_with_viewport(prop)
      prop == 'devicesWithViewport:'
    end

    def line_excludes_traffic(lines, idx)
      lines[idx + 1].exclude?('percentTraffic:')
    end
  end
end
