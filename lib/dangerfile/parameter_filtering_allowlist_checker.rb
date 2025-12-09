# frozen_string_literal: true

require_relative 'result'

# Checks if the ALLOWLIST constant in filter_parameter_logging.rb has been modified.
# Used by Dangerfile to warn reviewers about potential PII exposure risks.
# Note: Not wrapped in VSPDanger module to allow Dangerfile to require and use directly.
class ParameterFilteringAllowlistChecker
  FILTER_PARAM_FILE = 'config/initializers/filter_parameter_logging.rb'

  def initialize(base_sha: nil, head_sha: nil)
    @base_sha = base_sha
    @head_sha = head_sha
  end

  def run
    return Result.success('Parameter filtering allowlist is unchanged.') unless allowlist_changed?

    Result.warn(warning_message)
  end

  def allowlist_changed?
    return false if filter_params_diff.empty?

    in_allowlist = false
    filter_params_diff.split("\n").each do |line|
      # Track entry into ALLOWLIST array (handles both context and added/removed lines)
      clean_line = line.sub(/^[+-]/, '')
      if clean_line.include?('ALLOWLIST = %w[')
        in_allowlist = true
        next
      elsif in_allowlist && clean_line.include?('].freeze')
        in_allowlist = false
        next
      end

      next unless in_allowlist

      # Look for additions or deletions of array elements within ALLOWLIST
      next unless line.start_with?('+', '-') && !line.start_with?('+++', '---')

      element = line[1..].strip
      return true if element.match?(/^[a-z0-9_]+$/)
    end
    false
  end

  def filter_params_diff
    @filter_params_diff ||= `git diff #{@base_sha}...#{@head_sha} -- #{FILTER_PARAM_FILE}`
  end

  # Allow setting diff directly for testing
  attr_writer :filter_params_diff

  private

  def warning_message
    <<~EMSG
      ⚠️ **Parameter Filtering ALLOWLIST Modified**

      This PR modifies the `ALLOWLIST` constant in `config/initializers/filter_parameter_logging.rb`.

      **⚠️ CRITICAL: PII RISK**

      Adding keys to the ALLOWLIST means those parameters will **NOT** be filtered in logs across **ALL** of vets-api. This could expose sensitive data (PII/PHI/secrets) in logs.

      **Before approving this PR, verify:**
      - The added key(s) **CANNOT** contain PII, PHI, or secrets
      - The key name is generic enough that it won't accidentally expose sensitive data in another part of the application
      - The business need for unfiltering this parameter is documented in the PR description
      - Consider using the new `log_allowlist` parameter for per-call filtering instead (see #121130)

      **Per-call filtering alternative:**
      ```ruby
      # Instead of adding to global ALLOWLIST, use per-call allowlist:
      Rails.logger.info(data, log_allowlist: [:specific_key])
      ```

      **Documentation:**
      - [PII Guidelines](https://depo-platform-documentation.scrollhelp.site/developer-docs/personal-identifiable-information-pii-guidelines)
      - [Filter Parameter Logging](https://github.com/department-of-veterans-affairs/vets-api/blob/master/config/initializers/filter_parameter_logging.rb)

      <details>
        <summary>Modified ALLOWLIST diff</summary>

        ```diff
        #{filter_params_diff}
        ```
      </details>
    EMSG
  end
end
