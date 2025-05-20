require 'yaml'
require 'date' # For date parsing and age calculation

module FormEligibility
  class FormConnectorService
    # Updated: CONFIG_BASE_PATH now points to the forms_eligibility directory
    CONFIG_BASE_PATH = Rails.root.join('config', 'forms_eligibility')
    # Updated: ROUTING_RULES_PATH is now relative to the new CONFIG_BASE_PATH
    ROUTING_RULES_PATH = CONFIG_BASE_PATH.join('routing.yml')

    # Registry for transformation functions
    QUALIFYING_CHILD_RELATIONS = ["Daughter", "Son", "Stepson", "Stepdaughter"].freeze

    TRANSFORMATIONS = {
      'calculate_age' => ->(dob_str) do
        return nil if dob_str.blank?
        begin
          dob = Date.parse(dob_str)
          now = Date.today
          age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
          age
        rescue ArgumentError
          Rails.logger.warn "Invalid date string for age calculation: #{dob_str}"
          nil
        end
      end, # Comma was important here
      'check_for_qualifying_child_under_18' => ->(dependents_array) do
        return false unless dependents_array.is_a?(Array)

        # Accessing TRANSFORMATIONS directly as it's a class constant visible to the lambda
        calculate_age_fn = FormEligibility::FormConnectorService::TRANSFORMATIONS['calculate_age']

        dependents_array.any? do |dependent|
          next false unless dependent.is_a?(Hash)
          relation = dependent['dependentRelation']
          dob_str = dependent['dateOfBirth']

          next false unless QUALIFYING_CHILD_RELATIONS.include?(relation) # Use the constant
          next false if dob_str.blank?

          age = calculate_age_fn.call(dob_str)
          next false if age.nil?

          age < 18
        end
      end
      # Add other transformations here, e.g.:
      # 'to_uppercase' => ->(value) { value.is_a?(String) ? value.upcase : value }
    }.freeze

    def initialize
      # This logic should still work as full_routing_rules_path will be correctly constructed
      full_routing_rules_path = self.class.const_get(:ROUTING_RULES_PATH)
      @routing_rules = YAML.load_file(full_routing_rules_path)
    rescue Errno::ENOENT
      Rails.logger.error "Form routing rules file not found at #{full_routing_rules_path}"
      @routing_rules = {}
    rescue Psych::SyntaxError => e
      Rails.logger.error "Error parsing YAML in form routing rules at #{full_routing_rules_path}: #{e.message}"
      @routing_rules = {}
    end

    def suggest_forms(completed_form_id, submitted_data)
      suggestions = []
      current_form_id_str = completed_form_id.to_s
      return suggestions unless @routing_rules&.key?(current_form_id_str)

      form_config = @routing_rules[current_form_id_str]
      potential_forms = form_config['suggested_forms'] || []

      potential_forms.each do |target_form_config|
        rules_file_name = target_form_config['rules_file']
        next unless rules_file_name

        # rules_file_name (e.g., "rules/10-10D.yml") is now joined with the new CONFIG_BASE_PATH
        # resulting in config/forms_eligibility/rules/10-10D.yml, which is correct.
        rules_file_path = self.class.const_get(:CONFIG_BASE_PATH).join(rules_file_name)
        next unless File.exist?(rules_file_path)

        begin
          target_form_rules_data = YAML.load_file(rules_file_path)
          form_rules = target_form_rules_data['rules'] || []
          data_mapping_for_target = target_form_config['data_mapping'] || {}

          form_rules.each do |rule|
            rule_conditions = rule['if']
            if rule_conditions && evaluate_rule(rule_conditions, submitted_data, data_mapping_for_target)
              suggestion_details = rule['then'].dup
              suggestion_details['rule_name'] = rule['name']
              suggestion_details['target_form_id'] = target_form_config['target_form_id']
              suggestions << suggestion_details
            end
          end
        rescue Errno::ENOENT
          Rails.logger.error "Rules file not found: #{rules_file_path}"
        rescue Psych::SyntaxError => e
          Rails.logger.error "Error parsing YAML in rules file #{rules_file_path}: #{e.message}"
        rescue StandardError => e
          Rails.logger.error "Error processing rules for #{target_form_config['target_form_id']}: #{e.message} at #{e.backtrace.first}"
        end
      end
      suggestions
    end

    private

    def evaluate_rule(conditions, submitted_data, data_mapping)
      # Conditions is now expected to be an ARRAY of condition objects.
      # Each object: { "path": "some.path", "operator": "equals", "value": "expected" }
      return false unless conditions.is_a?(Array)

      conditions.all? do |condition_obj|
        unless condition_obj.is_a?(Hash) && condition_obj.key?('path') && condition_obj.key?('operator')
          Rails.logger.error "Invalid condition object format: #{condition_obj}"
          next false # Skip malformed condition, effectively making it fail the 'all?'
        end

        # 'value' is optional for some operators like 'is_present'
        actual_value = get_value_from_data(submitted_data, condition_obj['path'], data_mapping)
        expected_value = condition_obj['value']

        evaluate_condition_operator(actual_value, condition_obj['operator'], expected_value)
      end
    rescue StandardError => e
      Rails.logger.error "Error in evaluate_rule: #{e.message}. Conditions: #{conditions.inspect}"
      false
    end

    # New method to handle various comparison operators
    def evaluate_condition_operator(actual_value, operator, expected_value)
      case operator.to_s.downcase # Normalize operator string
      when "equals"
        actual_value == expected_value
      when "not_equals"
        actual_value != expected_value
      when "is_true"
        actual_value == true
      when "is_false"
        actual_value == false
      when "is_present" # Checks if the value is anything but nil
        !actual_value.nil?
      when "is_blank" # Checks if value is nil, or an empty string/array/hash
        actual_value.nil? ||
        (actual_value.respond_to?(:empty?) && actual_value.empty?)
      when "greater_than"
        return false if actual_value.nil? || expected_value.nil? # Ensure comparability for numeric types
        return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
        actual_value > expected_value
      when "less_than"
        return false if actual_value.nil? || expected_value.nil?
        return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
        actual_value < expected_value
      when "greater_than_or_equals"
        return false if actual_value.nil? || expected_value.nil?
        return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
        actual_value >= expected_value
      when "less_than_or_equals"
        return false if actual_value.nil? || expected_value.nil?
        return false unless actual_value.is_a?(Numeric) && expected_value.is_a?(Numeric)
        actual_value <= expected_value
      when "contains" # For strings or arrays
        if actual_value.is_a?(String) && expected_value.is_a?(String)
          actual_value.include?(expected_value)
        elsif actual_value.is_a?(Array)
          actual_value.include?(expected_value)
        else
          Rails.logger.warn "Unsupported types for 'contains' operator: actual_value type #{actual_value.class}, expected_value type #{expected_value.class}"
          false
        end
      when "in_list" # Checks if actual_value is one of the elements in expected_value (which should be an array)
        return false unless expected_value.is_a?(Array)
        expected_value.include?(actual_value)
      # TODO: Add more operators as needed: starts_with, ends_with, matches_regex, in_list, not_in_list, etc.
      else
        Rails.logger.warn "Unsupported operator: #{operator}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "Error in evaluate_condition_operator (operator: #{operator}, actual: #{actual_value.inspect}, expected: #{expected_value.inspect}): #{e.message}"
      false
    end

    def get_value_from_data(submitted_data, rule_condition_key_string, data_mapping)
      current_data_mapping = data_mapping || {}

      # Check if the rule_condition_key_string itself is a definition of a transformation in data_mapping
      mapping_entry = current_data_mapping[rule_condition_key_string]

      if mapping_entry.is_a?(Hash) && mapping_entry.key?('transform')
        transform_name = mapping_entry['transform']
        input_path = mapping_entry['input_path']
        transform_function = TRANSFORMATIONS[transform_name]

        if transform_function && input_path
          # Get the input value for the transformation. Note: This recursive call to get_value_from_data
          # ensures that input_path itself can be a direct path or another mapped/transformed value.
          # However, be cautious of circular dependencies if transforms call each other.
          input_value = get_value_from_data(submitted_data, input_path, data_mapping)
          return transform_function.call(input_value)
        else
          Rails.logger.warn "Transformation function '#{transform_name}' not found or input_path missing for '#{rule_condition_key_string}'."
          return nil
        end
      end

      # Original logic: if not a transform, treat rule_condition_key_string as a direct path or a key for a simple path mapping
      path_to_evaluate = mapping_entry.is_a?(String) ? mapping_entry : rule_condition_key_string

      unless path_to_evaluate.is_a?(String) # Could be a direct non-string key if not found in mapping_entry and used as is.
        # If it wasn't a string and not a transform, it implies a direct key lookup. Convert to string for dig.
        return submitted_data.dig(path_to_evaluate.to_s)
      end

      # If it doesn't include '.', it's a single key for dig.
      unless path_to_evaluate.include?('.')
        return submitted_data.dig(path_to_evaluate)
      end

      # Parse the path_to_evaluate for nested access, converting numeric parts to integers for array indexing.
      dig_path_parts = path_to_evaluate.split('.').map do |part|
        if part.match?(/\A-?\d+\z/) # Check if the part is an integer
          part.to_i
        else
          part.to_s # Keep as string for hash keys
        end
      end
      
      submitted_data.dig(*dig_path_parts)
    end
  end
end 