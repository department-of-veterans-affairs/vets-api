# frozen_string_literal: true

module ClaimsApi
  class VnpAtchmsService < ClaimsApi::LocalBGS
    def bean_name
      'VnpAtchmsWebServiceBean/VnpAtchmsService'
    end

    # Takes an object with a minimum of (other fields are camelized and passed to BGS):
    # vnp_proc_id: BGS procID
    # atchms_file_nm: File name
    # atchms_descp: File description
    # atchms_txt: Base64 encoded file or file path
    def vnp_atchms_create(opts)
      validate_opts! opts, %w[vnp_proc_id atchms_file_nm atchms_descp atchms_txt]

      convert_file! opts
      opts = jrn.merge(opts)
      arg_strg = convert_nil_values(opts)
      body = Nokogiri::XML::DocumentFragment.parse "<arg0>#{arg_strg}</arg0>"
      make_request(endpoint: 'VnpAtchmsWebServiceBean/VnpAtchmsService', action: 'vnpAtchmsCreate', body:,
                   key: 'return')
    end

    private

    def convert_file!(opts)
      opts.deep_symbolize_keys!
      txt = opts[:atchms_txt]
      raise ArgumentError, 'File must be a string' unless txt.is_a? String

      if File.exist?(txt)
        file = File.read(txt)
        opts[:atchms_txt] = Base64.encode64 file
      end
    end
  end
end
