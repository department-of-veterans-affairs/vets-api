# frozen_string_literal: true

module ClaimsApi
  # Logger for ClaimsApi, mostly used to format a print statement
  # Uses the standard Rails logger
  #
  #   ClaimsApi::Logger.log('526', claim_id: 'id_here')
  #   # => "ClaimsApi :: 526ez :: Claim ID: id_here"
  class Logger
    LEVELS = %i[debug info warn error fatal unknown].freeze

    def self.log(tag, **params)
      level = pick_level(**params)
      params.delete(:level)
      msg = format_msg(tag, **params)

      Rails.logger.send(level, msg)
      msg
    end

    def self.pick_level(**params)
      params.key?(:level) && params[:level].to_sym.in?(LEVELS) ? params[:level].to_sym : :info
    end

    def self.format_msg(tag, **params)
      msg = ['ClaimsApi', tag]
      msg.append("RID: #{params[:rid]}") if params[:rid].present?

      msg.append(params)

      called_from = caller_locations(2, 1).first
      msg.append("Location: #{called_from.path}:#{called_from.lineno}")
      msg.join(' :: ')
    end
  end
end

# Uncomment to allow a global (to claims_api) claims_log() method
# def claims_log(*tags, **params)
#   ClaimsApi::Logger.log(*tags, **params)
# end
