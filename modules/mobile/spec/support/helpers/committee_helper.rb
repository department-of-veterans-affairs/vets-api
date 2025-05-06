# frozen_string_literal: true

module CommitteeHelper
  include Committee::Rails::Test::Methods

  def committee_options
    @committee_options ||= {
      schema_path: Rails.root.join('modules', 'mobile', 'docs', 'openapi.json').to_s,
      prefix: '/mobile',
      strict_reference_validation: true,
      check_content_type: false
    }
  end
end
