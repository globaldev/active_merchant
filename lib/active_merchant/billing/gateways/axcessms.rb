require "cgi"

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class AxcessmsGateway < Gateway
      self.test_url = 'https://test.ctpe.net/frontend/payment.prc'
      self.live_url = 'https://ctpe.net/frontend/payment.prc'

      self.supported_countries = %w(AD AT BE BG BR CA CH CY CZ DE DK EE ES FI FO FR GB
                                    GI GR HR HU IE IL IM IS IT LI LT LU LV MC MT MX NL 
                                    NO PL PT RO RU SE SI SK TR US VA)
      
      self.supported_cardtypes = [:visa, :master, :american_express, :discover, :jcb, :maestro, :solo, ]

      self.homepage_url = 'http://www.axcessms.com/'
      self.display_name = 'Axcessms Gateway'
      self.money_format = :dollars
      self.default_currency = 'EUR'

      attr_accessor :logger
      attr_reader :auth_data
      
      # Creates a new Axcessms Gateway
      #
      # The gateway requires valid sender, login, password and channel are passed
      # in the +options+ hash.
      #
      
      def initialize(options={})
        requires!(options, :sender, :login, :password, :channel)
        super
        @auth_data = options
      end


      
      # Corresponds to CC.DB  in the POST documentation
      #
      def purchase(money, credit_card, options={})
        options[:credit_card] = credit_card
        commit('CC.DB', money, options)
      end

      # Corresponds to CC.PA  in the POST documentation
      #
      def authorize(money, credit_card, options={})
        options[:credit_card] = credit_card
        commit('CC.PA', money, options)
      end

      # Corresponds to CC.PA  in the POST documentation
      #
      def capture(money, authorization, options={})
        options[:authorization] = authorization
        commit('CC.CP', money, options)
      end

      # Corresponds to CC.RF  in the POST documentation
      #
      def refund(money, authorization, options={})
        options[:authorization] = authorization
        commit('CC.RF', money, options)
      end

      # Corresponds to CC.RV  in the POST documentation
      #
      def void(authorization, options={})
        options[:authorization] = authorization
        commit('CC.RV', nil, options)
      end

      private

      def commit(paymentcode, money, options)
        request = build_request(paymentcode, money, options)
        headers = { 
          'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8', 
          'Accept-Encoding' => 'identity;q=0;'
                  }
        #begin                  
          #puts request
          raw_response = ssl_post((test? ? test_url : live_url), post_data(request), headers)
  
          parsed = Hash[CGI.unescape(raw_response).scan(/([^=]+)=([^&]+)[&$]/)]
  
          Response.new(success?(parsed), response_message(parsed), parsed,
            :authorization => extract_authorization(parsed),
            :test => (parsed['TRANSACTION.MODE'] != 'LIVE')
          )
=begin          
        rescue ResponseError => e
          begin
            parsed = JSON.parse(e.response.body)
          rescue JSON::ParserError
            return Response.new(false, "Unable to parse error response: '#{e.response.body}'")
          end
          return Response.new(false, response_message(parsed), parsed, {})
        end
=end          
      end

      def build_request(paymentcode, money, options)
        post = Marshal.load(Marshal.dump(options))
        post['PAYMENT.CODE'] = paymentcode
        add_authentication(post)
        add_transaction(post)
        if options[:authorization]
          add_authorization(money, post)
        else  
          requires!(post, :credit_card)
          add_account(post)  
          add_payment(money, post)
          add_customer_data(post)
          add_address(post)
        end
        
        clean(post)
      end  
      
      def clean(post)
        post.delete(:credit_card)
        post.delete(:ruby)
        post.delete(:address)
        post.delete(:billing_address)
        post.delete(:authorization)
        post
      end

      def add_authentication(post)
        post['SECURITY.SENDER'] = @auth_data[:sender] 
        post['USER.LOGIN'] = @auth_data[:login]
        post['USER.PWD'] = @auth_data[:password]
        post['TRANSACTION.CHANNEL'] = @auth_data[:channel]
      end

      def add_payment(money, post)
        post['PRESENTATION.AMOUNT'] = amount(money)
        post['PRESENTATION.CURRENCY'] = post[:currency] || currency(money) || @default_currency
        post['PRESENTATION.USAGE'] = post[:order_id] || post[:invoice] || post['PRESENTATION.USAGE']  
      end
            
      def add_authorization(money, post)
        post['PRESENTATION.AMOUNT'] = amount(money) || post[:authorization]['PRESENTATION.AMOUNT']
        post['PRESENTATION.CURRENCY'] = currency(money) || post[:authorization]['PRESENTATION.CURRENCY']
        post['IDENTIFICATION.REFERENCEID'] = post['IDENTIFICATION.UNIQUEID'] || post[:authorization]['IDENTIFICATION.UNIQUEID']
        post['IDENTIFICATION.UNIQUEID'] = nil  
        post['IDENTIFICATION.SHORTID'] = nil
      end

      def add_customer_data(post)
        post['NAME.GIVEN'] = post[:credit_card].first_name
        post['NAME.FAMILY'] = post[:credit_card].last_name
      end

      def add_address(post)
        address = post[:billing_address] || post[:address]
        if !address.nil? 
          post['ADDRESS.STREET']=address[:street]
          post['ADDRESS.ZIP']=address[:zip]
          post['ADDRESS.CITY']=address[:city]
          post['ADDRESS.STATE']=address[:state]
          post['ADDRESS.COUNTRY']=address[:country]
        end
      end

      def add_account(post)
        post['ACCOUNT.HOLDER'] = "#{post[:credit_card].first_name} #{post[:credit_card].last_name}"
        post['ACCOUNT.NUMBER'] = post[:credit_card].number
        post['ACCOUNT.EXPIRY_MONTH'] = sprintf("%.2i", post[:credit_card].month)
        post['ACCOUNT.EXPIRY_YEAR'] = sprintf("%.4i", post[:credit_card].year)
        post['ACCOUNT.VERIFICATION'] = post[:credit_card].verification_value
      end

      def add_transaction(post)
        if post['TRANSACTION.MODE'].nil?
          post['TRANSACTION.MODE'] = 'INTEGRATOR_TEST'    
        end
        post['TRANSACTION.RESPONSE'] = 'SYNC'
      end

      def success?(response)
        response['PROCESSING.RETURN.CODE'] != nil ? response['PROCESSING.RETURN.CODE'][0..2] =='000' : false;
      end

      def response_message(parsed_response)
        parsed_response["PROCESSING.REASON"].nil? ? 
          parsed_response["PROCESSING.RETURN"] :
          parsed_response["PROCESSING.REASON"]  + " - " + parsed_response["PROCESSING.RETURN"]    
      end

      def extract_authorization(parsed)
        {
          'IDENTIFICATION.UNIQUEID' => parsed['IDENTIFICATION.UNIQUEID'],
          'IDENTIFICATION.SHORTID' => parsed['IDENTIFICATION.SHORTID'],
          'PRESENTATION.AMOUNT' => parsed['PRESENTATION.AMOUNT'],
          'PRESENTATION.CURRENCY' => parsed['PRESENTATION.CURRENCY'],
          'IDENTIFICATION.TRANSACTIONID' => parsed['IDENTIFICATION.TRANSACTIONID'],
          'TRANSACTION.MODE' => parsed['TRANSACTION.MODE'],
        }
      end

      def post_data(params)
        return nil unless params

        no_blanks = params.reject { |key, value| value.blank? }
        no_blanks.map { |key, value| "#{key}=#{CGI.escape(value.to_s)}" }.join("&")
      end
      
    end
  end
end