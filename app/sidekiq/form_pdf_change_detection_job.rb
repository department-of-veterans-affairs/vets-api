# frozen_string_literal: true

require 'forms/client'

# FormPdfChangeDetectionJob
#
# This Sidekiq job monitors VA form PDF revisions by comparing current SHA256 checksums
# against cached values to detect when forms have been updated.
#
# Why:
# - Enables automated tracking of form revisions for compliance and version management.
# - Provides metrics and logging for form change analytics and auditing.
# - Helps maintain awareness of form updates that may affect user experience.
#
# How:
# - Fetches current form data and SHA256 checksums from the VA Lighthouse Forms API.
# - Compares current checksums against cached values from previous runs.
# - Logs detected changes with StatsD metrics and detailed logging.
# - Updates the Rails cache with new checksums for future comparisons.
#
# See also: Forms::Client for API integration

class FormPdfChangeDetectionJob
  include Sidekiq::Job

  sidekiq_options retry: 10

  CACHE_TTL = 7.days.to_i.freeze # Keep longer than daily job frequency
  CACHE_PREFIX = 'form_pdf_revision_sha256'
  META_DATA = "[#{name}]".freeze

  def perform
    return unless Flipper.enabled?(:form_pdf_change_detection)

    Rails.logger.info("#{META_DATA} - Job started.")
    forms = fetch_forms_data

    cache_keys, current_sha_map = get_current_form_data(forms)
    cached_sha_map = Rails.cache.read_multi(*cache_keys)

    log_form_revisions(current_sha_map, cached_sha_map)
    update_cached_values(current_sha_map)

    Rails.logger.info("#{META_DATA} - Job finished successfully.")
  rescue => e
    Rails.logger.error("#{META_DATA} - Job raised an error: #{e.message}")
    raise e
  end

  private

  def fetch_forms_data
    response = Forms::Client.new(nil).get_all
    response.body['data']
  end

  def get_current_form_data(forms)
    cache_keys = []
    current_sha_map = {}

    forms.each do |form|
      form_id = form['id']
      current_sha256 = form.dig('attributes', 'sha256')

      next unless form_id && current_sha256

      cache_key = "#{CACHE_PREFIX}:#{form_id}"
      cache_keys << cache_key
      current_sha_map[cache_key] = {
        sha256: current_sha256,
        form:
      }
    rescue => e
      Rails.logger.error("#{META_DATA} - Error processing form #{form&.dig('id')}: #{e.message}")
    end

    [cache_keys, current_sha_map]
  end

  def update_cached_values(current_sha_map)
    cache_data = current_sha_map.transform_values { |data| data[:sha256] }
    Rails.cache.write_multi(cache_data, expires_in: CACHE_TTL) unless cache_data.empty?
  end

  def log_form_revisions(current_sha_map, cached_sha_map)
    current_sha_map.each do |cache_key, data|
      current_sha256 = data[:sha256]
      form = data[:form]
      last_known_sha256 = cached_sha_map[cache_key]

      log_form_revision(form['attributes'], form['id']) if last_known_sha256 && last_known_sha256 != current_sha256
    end
  end

  def log_form_revision(form_attributes, form_id)
    form_name = form_attributes['form_name']
    last_revision_on = form_attributes['last_revision_on']
    url = form_attributes['url']

    StatsD.increment('form.pdf.change.detected', tags: ["form:#{form_name}", "form_id:#{form_id}"])
    Rails.logger.info(
      "#{META_DATA} - PDF form #{form_name} (form_id: #{form_id}) was revised. " \
      "Last revised on date: #{last_revision_on}. " \
      "URL: #{url}"
    )
  end
end
