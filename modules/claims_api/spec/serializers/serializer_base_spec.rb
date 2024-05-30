# frozen_string_literal: true

require 'rails_helper'

require 'rspec'

class DummySerializer
  attr_reader :object

  def initialize(object)
    @object = object
  end

  def attributes
    {
      keep: 'this attribute',
      phase: 1,
      phase_change_date: 'abc',
      ever_phase_back: 'abc',
      current_phase_back: 'abc'
    }
  end
end

RSpec.describe ClaimsApi::SerializerBase do
  let(:dummy_class) do
    Class.new(DummySerializer) do
      include ClaimsApi::SerializerBase

      attr_accessor :phase
    end
  end
  let(:dummy_object) do
    Class.new do
      def status_from_phase(phase)
        phase
      end
    end
  end
  let(:sanitized_attributes) do
    {
      keep: 'this attribute'
    }
  end
  let(:dummy_instance) { dummy_class.new(dummy_object.new) }

  describe '#attributes' do
    it 'removes specified attributes from the hash' do
      result = dummy_instance.attributes
      expect(result).not_to include(:phase, :phase_change_date, :ever_phase_back, :current_phase_back)
      expect(result).to include(sanitized_attributes)
    end
  end

  describe '#status' do
    it 'returns the status based on the phase' do
      allow(dummy_instance).to receive(:phase).and_return(1)
      expect(dummy_instance.status).to eq(1)
    end
  end
end
