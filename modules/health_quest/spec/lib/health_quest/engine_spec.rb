
require 'rails_helper'
# require_relative '../../../lib/health_quest/engine'

describe HealthQuest::Engine do
  # include HealthQuest

  it 'is a module' do
  	expect(HealthQuest::Engine.class).to eq(Class)
  	expect(HealthQuest::Engine.methods.grep(/new/).length).to eq(0)
  end

end