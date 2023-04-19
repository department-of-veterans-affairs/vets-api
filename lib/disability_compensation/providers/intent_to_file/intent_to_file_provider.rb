# frozen_string_literal: true

module IntentToFileProvider
  def self.get_intent_to_file
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end

  def self.create_intent_to_file(type)
    raise NotImplementedError, 'Do not use base module methods. Override this method in implementation class.'
  end
end
