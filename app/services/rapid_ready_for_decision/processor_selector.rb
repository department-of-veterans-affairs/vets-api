# frozen_string_literal: true

module RapidReadyForDecision
  class ProcessorSelector
    def initialize(form526_submission)
      @form526_submission = form526_submission
    end

    RrdConstants = RapidReadyForDecision::Constants

    def processor_class(backup: false)
      return unless rrd_enabled?

      # single-issue claims only
      return unless mapped_submission_disabilities.size == 1

      disability_symbol = mapped_submission_disabilities.first
      # must be a disability supported by RRD
      return unless disability_symbol

      disability_struct = RrdConstants::DISABILITIES[disability_symbol]
      # the RRD disability must be enabled
      return unless rrd_enabled_disability?(disability_struct)

      form_disability = form_disabilities.first
      # the submitted disability must be for a claim for increase
      return unless self.class.disability_increase?(form_disability, disability_struct)

      return disability_struct[:backup_processor_class]&.constantize if backup

      disability_struct[:processor_class]&.constantize
    end

    def rrd_applicable?
      !processor_class.nil?
    end

    def self.disability_increase?(form_disability, disability_struct)
      form_disability['diagnosticCode'] == disability_struct[:code] &&
        form_disability['disabilityActionType']&.upcase == 'INCREASE'
    end

    def send_rrd_alert(message)
      body = <<~BODY
        Environment: #{Settings.vsp_environment}<br/>
        Form526Submission.id: #{@form526_submission.id}<br/>
        <br/>
        #{message}
      BODY
      ActionMailer::Base.mail(
        from: ApplicationMailer.default[:from],
        to: Settings.rrd.alerts.recipients,
        subject: 'RRD Processor Selector alert',
        body: body
      ).deliver_now
    end

    private

    def rrd_enabled?
      # In next PR, change this to be a Flipper configuration to disable RRD completely
      true
    end

    # @return [Boolean] Is the specified disability RRD-enabled according to Flipper settings
    def rrd_enabled_disability?(disability_struct)
      # Todo later: Remove old RRD-related Flipper keys "disability_#{disability.downcase}_compensation_fast_track"
      Flipper.enabled?("rrd_#{disability_struct[:flipper_name].downcase}_compensation".to_sym) ||
        Flipper.enabled?("disability_#{disability_struct[:flipper_name].downcase}_compensation_fast_track".to_sym)
    end

    def form_disabilities
      @form_disabilities ||= @form526_submission.form.dig('form526', 'form526', 'disabilities')
    end

    def mapped_submission_disabilities
      @mapped_submission_disabilities ||= RrdConstants.extract_disability_symbol_list(@form526_submission)
    end
  end
end
