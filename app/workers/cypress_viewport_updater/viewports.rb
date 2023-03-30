# frozen_string_literal: true

module CypressViewportUpdater
  class Viewports
    NUM_TOP_VIEWPORTS = { mobile: 5, tablet: 5, desktop: 5 }.freeze

    def initialize(user_report:)
      @total_users = user_report.data.totals.first.values.first.to_f
      @viewports = { mobile: [], tablet: [], desktop: [] }
    end

    def create(viewport_report:)
      count = { mobile: 0, tablet: 0, desktop: 0 }

      viewport_report.data.rows.each do |row|
        viewport_type = row.dimensions.first.to_sym

        if @viewports[viewport_type].count < NUM_TOP_VIEWPORTS[viewport_type] &&
           width_and_height_set?(row)
          count[viewport_type] += 1
          @viewports[viewport_type] << make_viewport(row:, rank: count[viewport_type])
        end

        break if viewports_full?
      end

      self
    end

    def mobile
      @viewports[:mobile]
    end

    def tablet
      @viewports[:tablet]
    end

    def desktop
      @viewports[:desktop]
    end

    private

    def width_and_height_set?(row)
      row.dimensions[1] != '(not set)'
    end

    def make_viewport(row:, rank:)
      CypressViewportUpdater::
        Viewport.new(row:,
                     rank:,
                     total_users: @total_users)
    end

    def viewports_full?
      @viewports[:mobile].count >= NUM_TOP_VIEWPORTS[:mobile] &&
        @viewports[:tablet].count >= NUM_TOP_VIEWPORTS[:tablet] &&
        @viewports[:desktop].count >= NUM_TOP_VIEWPORTS[:desktop]
    end
  end
end
