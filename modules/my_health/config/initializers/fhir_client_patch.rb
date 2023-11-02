# frozen_string_literal: true

# This monkeypatch will prevent the Ruby FHIR client from printing (to INFO-level logs) information
# that can identify the veteran who made the request.
# Patched version: fhir_client (5.0.3)
module FHIR
  class Client
    alias original_get get # Create a reference to the original method

    def get(path, headers = {})
      if Flipper.enabled?(:mhv_medical_records_redact_fhir_client_logs,
                          @current_user)

        # Modify URL for logging
        redacted_url = redact_url_ids(Addressable::URI.parse(build_url(path)).to_s)

        # Temporarily disable the logger's info method
        original_info = FHIR.logger.method(:info)
        FHIR.logger.define_singleton_method(:info) { |_| }

        # Call the original method without printing the URL
        response = original_get(path, headers)

        # Restore the original logger's info method
        FHIR.logger.define_singleton_method(:info, original_info)

        # Log the redacted URL
        FHIR.logger.info "GETTING: #{redacted_url}"

        response
      else
        original_get(path, headers)
      end
    end

    private

    def redact_url_ids(url)
      # Replace all IDs with X's
      url = url.gsub(/([?&](identifier|patient)=)\d+/i) { |m| m.sub(/\d+$/, 'XXXXX') }
      url.gsub(%r{(?<=/)\d+}i, 'XXXXX')
    end
  end
end
