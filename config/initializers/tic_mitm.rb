# frozen_string_literal: true

# Due to the requirement of VA's Trusted Internet Connection (TIC), we need to enable legacy server connections.
# OpenSSL 1.x's implementation didn't prohibit MitM proxying like the TIC from working but to guard against
# CVE-2009-3555, OpenSSL 3.x's does.

# Enable legacy server connections
OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_LEGACY_SERVER_CONNECT
