
require 'rails_helper'
# require_relative '../../../lib/health_quest'

describe HealthQuest do
  include HealthQuest

  it 'is a module' do
  	expect(HealthQuest.class).to eq(Module)
  	expect(HealthQuest.team_name).to eq('Health Care Experience Team')
  end

end