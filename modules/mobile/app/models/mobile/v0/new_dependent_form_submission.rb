# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class NewDependentFormSubmission < Common::Resource
      attribute :id, Types::String
      attribute :submit_form_job_id, Types::String
    end
  end
end
