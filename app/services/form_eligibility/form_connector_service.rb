require 'yaml'
require 'date' # For date parsing and age calculation

module FormEligibility
  class FormConnectorService
    # Updated: CONFIG_BASE_PATH now points to the forms_eligibility directory
    CONFIG_BASE_PATH = Rails.root.join('config', 'forms_eligibility')
    # Updated: ROUTING_RULES_PATH is now relative to the new CONFIG_BASE_PATH
    ROUTING_RULES_PATH = CONFIG_BASE_PATH.join('routing.yml')

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
      return false unless conditions.is_a?(Hash) && submitted_data.respond_to?(:dig)

      conditions.all? do |condition_key_str, expected_value|
        condition_key = condition_key_str.to_s # Ensure it's a string

        case condition_key
        when "sc_disability_is_permanent_and_total"
          va_comp_type_path = data_mapping[condition_key]
          actual_va_comp_type = va_comp_type_path ? submitted_data.dig(*va_comp_type_path.split('.')) : nil
          (actual_va_comp_type == "highDisability") == expected_value
        when "child_is_eligible_age_or_status"
          dob_path = data_mapping["child_date_of_birth"]
          attended_school_path = data_mapping["child_attended_school_last_year"]

          child_dob_str = dob_path ? submitted_data.dig(*dob_path.split('.')) : nil
          attended_school = attended_school_path ? submitted_data.dig(*attended_school_path.split('.')) : false
          
          is_eligible = false
          if child_dob_str
            begin
              age = calculate_age(Date.parse(child_dob_str))
              is_eligible = (age < 18) || (age < 23 && attended_school == true)
            rescue ArgumentError
              Rails.logger.warn "Invalid date string for child_date_of_birth: #{child_dob_str}"
              is_eligible = false
            end
          end
          is_eligible == expected_value
        else
          actual_value = get_value_from_data(submitted_data, condition_key, data_mapping)
          if expected_value.is_a?(Array)
            expected_value.include?(actual_value)
          else
            actual_value == expected_value
          end
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error in evaluate_rule: #{e.message}. Conditions: #{conditions}"
      false
    end

    def get_value_from_data(submitted_data, rule_condition_key_string, data_mapping)
      current_data_mapping = data_mapping || {}
      path_from_mapping = current_data_mapping[rule_condition_key_string]

      if path_from_mapping
        dig_path_parts = path_from_mapping.split('.').map(&:to_s)
        submitted_data.dig(*dig_path_parts)
      else
        submitted_data.dig(rule_condition_key_string)
      end
    end

    def calculate_age(date_of_birth)
      return nil unless date_of_birth.is_a?(Date)
      now = Date.today
      age = now.year - date_of_birth.year - ((now.month > date_of_birth.month || (now.month == date_of_birth.month && now.day >= date_of_birth.day)) ? 0 : 1)
      age
    end
  end
end 