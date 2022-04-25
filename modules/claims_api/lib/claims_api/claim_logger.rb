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
      case tag
      when '526'
        msg.append("Claim ID: #{params[:claim_id]}") if params[:claim_id].present?
        msg.append("Detail: #{params[:detail]}") if params[:detail].present?
        msg.append("VBMS ID: #{params[:vbms_id]}") if params[:vbms_id].present?
        msg.append("autoCestPDFGenerationDisabled: #{params[:pdf_gen_dis]}") if params[:pdf_gen_dis].present?
        msg.append("Attachment ID: #{params[:attachment_id]}") if params[:attachment_id].present?
      when 'poa'
        msg.append("POA ID: #{params[:poa_id]}") if params[:poa_id].present?
        msg.append("Detail: #{params[:detail]}") if params[:detail].present?
        msg.append("Error Code: #{params[:error]}") if params[:error].present?
      when 'itf'
        msg.append("ITF: #{params[:detail]}") if params[:detail].present?
      else
        msg.append(params.to_json)
      end
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
