# frozen_string_literal: true

# since the httpclient gem uses its own certificate store, force HTTPI to use :net_http
HTTPI.adapter = :net_http
HTTPI.log = false
