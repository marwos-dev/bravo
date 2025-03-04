# -*- encoding: utf-8 -*-
module Bravo
  # Authorization class. Handles interactions wiht the WSAA, to provide
  # valid key and signature that will last for a day.
  #
  class Wsaa
    TA_EXPIRATION_TIME = 43200 # 12 hours
    # Main method for authentication and authorization.
    # When successful, produces the yaml file with auth data.
    #
    def self.login
      tra   = build_tra
      cms   = build_cms(tra)
      req   = build_request(cms)
      auth  = call_wsaa(req)

      write_yaml(auth)
    end

    # Builds the xml for the 'Ticket de Requerimiento de Acceso'
    # @return [String] containing the request body
    #
    # rubocop:disable Metrics/MethodLength
    def self.build_tra
      now = (Time.now) - 120
      @from = now.strftime('%FT%T%:z')
      @to   = (now + TA_EXPIRATION_TIME).strftime('%FT%T%:z')
      @id   = now.strftime('%s')
      tra  = <<-EOF
<?xml version="1.0" encoding="UTF-8"?>
<loginTicketRequest version="1.0">
  <header>
    <uniqueId>#{ @id }</uniqueId>
    <generationTime>#{ @from }</generationTime>
    <expirationTime>#{ @to }</expirationTime>
  </header>
  <service>wsfe</service>
</loginTicketRequest>
EOF
      tra
    end
    # rubocop:enable Metrics/MethodLength
    # Builds the CMS
    # @return [String] cms
    #
    def self.build_cms(tra)
      `echo '#{ tra }' |
        #{ Bravo.openssl_bin } cms -sign -in /dev/stdin -signer #{ Bravo.cert } -inkey #{ Bravo.pkey } \
        -nodetach -outform der |
        #{ Bravo.openssl_bin } base64 -e`
    end

    # Builds the CMS request to log in to the server
    # @return [String] the cms body
    #
    def self.build_request(cms)
      # rubocop:disable Metrics/LineLength
      request = <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://wsaa.view.sua.dvadac.desein.afip.gov">
  <SOAP-ENV:Body>
    <ns1:loginCms>
      <ns1:in0>
#{ cms }
      </ns1:in0>
    </ns1:loginCms>
  </SOAP-ENV:Body>
</SOAP-ENV:Envelope>
XML
      request
    end
    # rubocop:enable Metrics/LineLength

    # Calls the WSAA with the request built by build_request
    # @return [Array] with the token and signature
    #
    def self.call_wsaa(req)
      response = `echo '#{ req }' |
        curl -k -s -H 'Content-Type: application/soap+xml; action=""' -d @- #{ Bravo::AuthData.wsaa_url }`

      response = CGI::unescapeHTML(response)
      response_login_errors(response)
      token = response.scan(%r{\<token\>(.+)\<\/token\>}).first.first
      sign  = response.scan(%r{\<sign\>(.+)\<\/sign\>}).first.first
      [token, sign]
    end

    # Writes the token and signature to a YAML file in the /tmp directory
    #
    def self.write_yaml(certs)
      yml = <<-YML
token: #{certs[0]}
sign: #{certs[1]}
expire_at: #{Time.new + TA_EXPIRATION_TIME}
YML
      `echo '#{ yml }' > /tmp/bravo_#{ Bravo.cuit }_#{ Time.new.strftime('%Y_%m_%d') }.yml`
    end

    def response_login_errors(response)
      raise "No se obtuvo respuesta al realizar el Login" if response.blank?
      cms_error = response.scan(%r{\<faultstring\>(.+)\<\/faultstring\>})
      raise cms_error.first.first if cms_error.present?
      token_response = response.scan(%r{\<token\>(.+)\<\/token\>})
      raise "Error obteniendo el Token" if token_response.length != 1
      sign_response = response.scan(%r{\<sign\>(.+)\<\/sign\>})
      raise "Error obteniendo Sign" if sign_response.length != 1
    end

  end
end
