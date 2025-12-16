# frozen_string_literal: true

require 'rails_helper'
require 'dangerfile/parameter_filtering_allowlist_checker'

RSpec.describe Dangerfile::ParameterFilteringAllowlistChecker do
  subject(:checker) { described_class.new }

  describe '#allowlist_changed?' do
    context 'when a parameter is added to ALLOWLIST' do
      let(:diff) do
        <<~DIFF
          diff --git a/config/initializers/filter_parameter_logging.rb b/config/initializers/filter_parameter_logging.rb
          --- a/config/initializers/filter_parameter_logging.rb
          +++ b/config/initializers/filter_parameter_logging.rb
          @@ -5,6 +5,7 @@ ALLOWLIST = %w[
             action
             benefits_intake_uuid
          +  new_param
             bpds_uuid
           ].freeze
        DIFF
      end

      it 'returns true' do
        checker.filter_params_diff = diff
        expect(checker.allowlist_changed?).to be true
      end
    end

    context 'when a parameter is removed from ALLOWLIST' do
      let(:diff) do
        <<~DIFF
          diff --git a/config/initializers/filter_parameter_logging.rb b/config/initializers/filter_parameter_logging.rb
          --- a/config/initializers/filter_parameter_logging.rb
          +++ b/config/initializers/filter_parameter_logging.rb
          @@ -5,7 +5,6 @@ ALLOWLIST = %w[
             action
          -  benefits_intake_uuid
             bpds_uuid
           ].freeze
        DIFF
      end

      it 'returns true' do
        checker.filter_params_diff = diff
        expect(checker.allowlist_changed?).to be true
      end
    end

    context 'when changes are outside the ALLOWLIST section' do
      let(:diff) do
        <<~DIFF
          diff --git a/config/initializers/filter_parameter_logging.rb b/config/initializers/filter_parameter_logging.rb
          --- a/config/initializers/filter_parameter_logging.rb
          +++ b/config/initializers/filter_parameter_logging.rb
          @@ -1,5 +1,5 @@
          -# Do NOT add keys that can contain PII/PHI/secrets.
          +# Do NOT add parameters that can contain PII/PHI/secrets.
        DIFF
      end

      it 'returns false' do
        checker.filter_params_diff = diff
        expect(checker.allowlist_changed?).to be false
      end
    end

    context 'when there are no changes to the file' do
      it 'returns false' do
        checker.filter_params_diff = ''
        expect(checker.allowlist_changed?).to be false
      end
    end

    context 'when changes are after the ALLOWLIST section' do
      let(:diff) do
        <<~DIFF
          diff --git a/config/initializers/filter_parameter_logging.rb b/config/initializers/filter_parameter_logging.rb
          --- a/config/initializers/filter_parameter_logging.rb
          +++ b/config/initializers/filter_parameter_logging.rb
          @@ -80,6 +80,7 @@ Rails.application.config.filter_parameters = [
             lambda do |k, v|
               case v
               when Hash
          +      # Added comment
                 v.each do |nested_key, nested_value|
        DIFF
      end

      it 'returns false' do
        checker.filter_params_diff = diff
        expect(checker.allowlist_changed?).to be false
      end
    end
  end

  describe '#run' do
    context 'when ALLOWLIST is modified' do
      let(:diff) do
        <<~DIFF
          diff --git a/config/initializers/filter_parameter_logging.rb b/config/initializers/filter_parameter_logging.rb
          @@ -5,6 +5,7 @@ ALLOWLIST = %w[
             action
          +  new_param
           ].freeze
        DIFF
      end

      it 'returns a warning result' do
        checker.filter_params_diff = diff
        result = checker.run
        expect(result.severity).to eq(Dangerfile::Result::WARNING)
      end

      it 'includes PII risk warning in message' do
        checker.filter_params_diff = diff
        result = checker.run
        expect(result.message).to include('PII RISK')
      end

      it 'includes review checklist in message' do
        checker.filter_params_diff = diff
        result = checker.run
        expect(result.message).to include('Before approving this PR, verify')
      end
    end

    context 'when ALLOWLIST is not modified' do
      it 'returns a success result' do
        checker.filter_params_diff = ''
        result = checker.run
        expect(result.severity).to eq(Dangerfile::Result::SUCCESS)
      end
    end
  end
end
