# frozen_string_literal: true

require 'rails_helper'
require CovidResearch::Engine.root.join('spec', 'rails_helper.rb')
require_relative '../../../../app/serializers/covid_research/volunteer/facility_serializer'

RSpec.describe CovidResearch::Volunteer::FacilitySerializer do
  let(:subject) { described_class.new }

  let(:payload) do
    {
      'preferredFacility' => 'Bay Pines VA Medical Center|vha_516'
    }
  end

  describe '#serialize' do
    it 'modifies the facility attribute' do
      expect(subject.serialize(payload)).to include({ QuestionName: 'preferredFacility',
                                                      QuestionValue: 'Bay Pines VA Medical Center|vha_516' })
    end
  end
end
