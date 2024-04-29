# frozen_string_literal: true

module ClaimsApi
  module BGSHelpers
    def convert_nil_values(options)
      arg_strg = ''
      options.each do |option|
        arg = option[0].to_s.camelize(:lower)
        arg_strg += (option[1].nil? ? "<#{arg} xsi:nil='true'/>" : "<#{arg}>#{option[1]}</#{arg}>")
      end
      arg_strg
    end

    def validate_opts!(opts, required_keys)
      keys = opts.keys.map(&:to_s)
      required_keys = required_keys.map(&:to_s)
      missing_keys = required_keys - keys
      raise ArgumentError, "Missing required keys: #{missing_keys.join(', ')}" if missing_keys.present?
    end

    def jrn
      {
        jrn_dt: Time.current.iso8601,
        jrn_lctn_id: Settings.bgs.client_station_id,
        jrn_status_type_cd: 'U',
        jrn_user_id: Settings.bgs.client_username,
        jrn_obj_id: Settings.bgs.application
      }
    end

    def to_camelcase(claim:)
      claim.deep_transform_keys { |k| k.to_s.camelize(:lower) }
    end
  end
end
