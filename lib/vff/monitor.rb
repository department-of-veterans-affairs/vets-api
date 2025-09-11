# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module VFF
  #
  # Monitor functions for Rails logging and StatsD for VFF (Vets Forms Frontend) forms
  #
  class Monitor < ::ZeroSilentFailures::Monitor
    # VFF (Vets Forms Frontend) form IDs that are processed through SimpleFormsApi
    VFF_FORM_IDS = %w[21-0966 21-4142 21-10210 21-0972 21P-0847 20-10206 20-10207 21-0845].freeze

    def initialize
      super('vff-application')
    end

    # Check if a form ID is a VFF form
    #
    # @param form_id [String] the form ID to check
    # @return [Boolean] true if the form is a VFF form
    def self.vff?(form_id)
      VFF_FORM_IDS.include?(form_id)
    end
  end
end
