# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    module Configuration
      class VffConfig < Base
        def s3_settings
          Settings.vff_simple_forms.aws
        end
      end
    end
  end
end
