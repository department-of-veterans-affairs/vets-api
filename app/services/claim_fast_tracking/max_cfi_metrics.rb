# frozen_string_literal: true

module ClaimFastTracking
  class MaxCfiMetrics
    include SentryLogging

    attr_reader :form, :form_data, :metadata

    MAX_CFI_STATSD_KEY_PREFIX = 'api.max_cfi'

    # Triggers any relevant StatsD metrics calls whenever a 526EZ InProgressForm is updated with
    # a new params hash. The params[:metadata] hash will be mutated to include any metadata
    # needed by this CFI metrics logic.
    def self.log_form_update(form, params)
      new(form, params).log_form_update if form.form_id == '21-526EZ'
    end

    def initialize(form, params)
      params[:metadata] ||= {}
      @form = form
      @form_data = params[:form_data] || params[:formData]
      @form_data = JSON.parse(form_data) if form_data.is_a?(String)
      @metadata = params[:metadata]
    end

    # Max CFI metrics progress is stored in InProgressForm#metadata, to prevent double-counting
    # events over the IPF's lifecycle. This method will create-or-load the progress metadata
    # from the IPF, and updates an older scheme where the progress was just a boolean.
    def create_or_load_metadata
      cfi_metadata = form.metadata['cfiMetric']
      if cfi_metadata.blank?
        { 'initLogged' => false, 'cfiLogged' => false }
      elsif cfi_metadata == true
        { 'initLogged' => true, 'cfiLogged' => true }
      else
        cfi_metadata
      end
    end

    def log_form_update
      cfi_metadata = create_or_load_metadata
      unless cfi_metadata['initLogged']
        log_init_metric
        cfi_metadata['initLogged'] = true
      end
      if claiming_increase? && !cfi_metadata['cfiLogged']
        log_cfi_metric
        cfi_metadata['cfiLogged'] = true
      end
      metadata['cfiMetric'] = cfi_metadata
    rescue => e
      # Log the exception but but do not fail, otherwise in-progress form will not update
      Rails.logger.error("In-progress form failed to log Max CFI metrics: #{e.message}")
      log_exception_to_sentry(e)
    end

    def claiming_increase?
      form_data&.dig('view:claim_type', 'view:claiming_increase') ||
        form_data&.dig('view:claimType', 'view:claimingIncrease')
    end

    def rated_disabilities
      form_data&.dig('rated_disabilities') || form_data&.dig('ratedDisabilities') || []
    end

    def max_rated_disabilities
      rated_disabilities.filter do |dis|
        maximum_rating_percentage = dis['maximum_rating_percentage'] || dis['maximumRatingPercentage']
        rating_percentage = dis['rating_percentage'] || dis['ratingPercentage']
        maximum_rating_percentage.present? && maximum_rating_percentage == rating_percentage
      end
    end

    def max_rated_disabilities_diagnostic_codes
      max_rated_disabilities.map { |dis| dis['diagnosticCode'] || dis['diagnostic_code'] }
    end

    private

    def log_init_metric
      StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.on_526_started",
                       tags: ["has_max_rated:#{max_rated_disabilities.any?}"])
      max_rated_disabilities_diagnostic_codes.each do |dc|
        StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.526_started", tags: ["diagnostic_code:#{dc}"])
      end
    end

    def log_cfi_metric
      StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.on_rated_disabilities",
                       tags: ["has_max_rated:#{max_rated_disabilities.any?}"])
      max_rated_disabilities_diagnostic_codes.each do |dc|
        StatsD.increment("#{MAX_CFI_STATSD_KEY_PREFIX}.rated_disabilities", tags: ["diagnostic_code:#{dc}"])
      end
    end
  end
end
