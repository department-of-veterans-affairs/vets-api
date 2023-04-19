# frozen_string_literal: true

require 'disability_compensation/providers/intent_to_file/intent_to_file_provider'
require 'disability_compensation/responses/intent_to_files_response'
require 'evss/intent_to_file/service'

class EvssIntentToFileProvider
  include IntentToFileProvider
  def initialize(current_user)
    @service = EVSS::IntentToFile::Service.new(current_user)
  end

  def get_intent_to_file
    @service.get_intent_to_file
  end

  def create_intent_to_file(type)
    @service.create_intent_to_file(type)
  end
end
