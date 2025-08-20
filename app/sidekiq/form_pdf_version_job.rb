# frozen_string_literal: true

require 'forms/client'

class FormPdfVersionJob
  include Sidekiq::Job

  sidekiq_options retry: 4

  CACHE_TTL = 7.days.to_i.freeze # Keep longer than daily job frequency
  CACHE_PREFIX = 'form_pdf_revision_sha256'

  def perform
    response = Forms::Client.new(nil).get_all

    forms = response.body['data']

    forms.each do |form|
      check_for_revision(form)
    rescue => e
      Rails.logger.error "Error processing form #{form&.dig('id')}: #{e.message}"
      # Continue processing other forms
    end
  rescue => e
    Rails.logger.error "Error in FormPdfVersionJob: #{e.message}"
    raise e
  end

  private

  def check_for_revision(form)
    form_id = form['id']
    attributes = form['attributes']
    current_sha256 = attributes['sha256']

    cache_key = "#{CACHE_PREFIX}:#{form_id}"
    last_known_sha256 = Rails.cache.read(cache_key)

    update_revision(attributes, form_id) if last_known_sha256 && last_known_sha256 != current_sha256

    # Always update cache with the latest hash for the next run
    Rails.cache.write(cache_key, current_sha256, expires_in: CACHE_TTL)
  end

  def update_revision(form_attributes, form_id)
    form_name = form_attributes['form_name']
    last_revision_on = form_attributes['last_revision_on']

    StatsD.increment('form.pdf.change.detected', tags: ["form:#{form_name}", "form_id:#{form_id}"])
    Rails.logger.info(<<~MESSAGE)
      PDF form #{form_name} (form_id: #{form_id}) was revised.
      Last revised on date: #{last_revision_on}
    MESSAGE
  end
end
