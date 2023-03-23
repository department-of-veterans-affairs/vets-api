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

    # rubocop:disable Metrics/MethodLength
    def self.format_msg(tag, **params) # rubocop:disable Metrics/AbcSize
      msg = ['ClaimsApi', tag]
      msg.append("RID: #{params[:rid]}") if params[:rid].present?
      case tag
      when '526'
        msg.append("Claim ID: #{params[:claim_id]}") if params[:claim_id].present?
        msg.append("Detail: #{params[:detail]}") if params[:detail].present?
        msg.append("VBMS ID: #{params[:vbms_id]}") if params[:vbms_id].present?
        msg.append("autoCestPDFGenerationDisabled: #{params[:pdf_gen_dis]}") if params[:pdf_gen_dis].present?
        msg.append("Attachment ID: #{params[:attachment_id]}") if params[:attachment_id].present?
      when 'poa'
        msg.append("POA ID: #{params[:poa_id]}") if params[:poa_id].present?
        msg.append("POA Code: #{params[:poa_code]}") if params[:poa_code].present?
        msg.append("Detail: #{params[:detail]}") if params[:detail].present?
        msg.append("Error Code: #{params[:error]}") if params[:error].present?
      when 'itf'
        msg.append("ITF: #{params[:detail]}") if params[:detail].present?
      when 'validate_identifiers'
        msg.append("ICN: #{params[:icn]}") if params[:icn].present?
        msg.append("BIRLS Required: #{params[:require_birls]}") if params[:require_birls].present?
        msg.append("Header Request: #{params[:header_request]}") if params[:header_request].present?
        msg.append("has ptcpnt_id: #{params[:ptcpnt_id]}") if params[:ptcpnt_id].present?
        msg.append("has birls_id: #{params[:birls_id]}") if params[:birls_id].present?
        msg.append("MPI Response OK: #{params[:mpi_res_ok]}") if params[:mpi_res_ok].present?
      when 'multiple_ids'
        msg.append("Header Request: #{params[:header_request]}") if params[:header_request].present?
        msg.append("ICN: #{params[:icn]}") if params[:icn].present?
        msg.append("# of IDs: #{params[:ptcpnt_ids]}") if params[:ptcpnt_ids].present?
      when 'local_bgs'
        params.each do |k, v|
          msg.append "#{k}: #{v}"
        end
      else
        msg.append(params.to_json)
      end
      called_from = caller_locations(2, 1).first
      msg.append("Location: #{called_from.path}:#{called_from.lineno}")
      msg.join(' :: ')
    end
    # rubocop:enable Metrics/MethodLength
  end
end

# Uncomment to allow a global (to claims_api) claims_log() method
# def claims_log(*tags, **params)
#   ClaimsApi::Logger.log(*tags, **params)
# end
