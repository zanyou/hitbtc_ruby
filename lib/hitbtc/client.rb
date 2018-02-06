require 'httparty'
require 'base64'
require 'addressable/uri'


module Hitbtc
  class Client
    include HTTParty

    def initialize(api_key=nil, api_secret=nil, options={})
      @api_key      = api_key || YAML.load_file("key.yml")["key"]
      @api_secret   = api_secret || YAML.load_file("key.yml")["secret"]
      @api_version  = options[:version] ||= '2'
      @base_uri     = options[:base_uri] ||= 'api.hitbtc.com'
    end

    ###########################
    ###### Public Data ########
    ###########################

    def symbols
        get_public 'symbol'
    end

    def ticker symbol
      get_public("ticker/"+symbol.upcase)
    end

    def order_book symbol, opts={}
      #opts parameter
      #limit (number): Limit of orderbook levels, default 100. Set 0 to view full orderbook levels
      get_public("orderbook/"+symbol.upcase, opts)
    end

    def trades symbol, from = (Time.now - 1.day).to_i, by = "ts", start_index = 0, max_results = 1000, opts={}
      #Parameter                    Type                            Description
      #from	required                int = trade_id or timestamp	    returns trades with trade_id > specified trade_id or returns trades with timestamp >= specified timestamp
      #till	optional                int = trade_id or timestamp	    returns trades with trade_id < specified trade_id or returns trades with timestamp < specified timestamp
      #by	required                  filter and sort by trade_id or ts (timestamp)
      #sort	optional                asc (default) or desc
      #start_index required         int	zero-based
      #max_results required         int, max value = 1000
      #format_item optional         "array" (default) or "object"
      #format_price	optional        "string" (default) or "number"
      #format_amount optional       "string" (default) or "number"
      #format_amount_unit optional  "currency" (default) or "lot"
      #format_tid	optional          "string" or "number" (default)
      #format_timestamp	optional    "millisecond" (default) or "second"
      #format_wrap optional         "true" (default) or "false"
      if by != "trade_id" && by != "ts"
        raise "3rd parameter by, should be 'trade_id' or 'ts'"
      end
      opts[:from] = from
      opts[:start_index] = start_index
      opts[:max_results] = max_results
      opts[:by] = by
      opts[:symbol] = symbol.upcase
      mash= get_public('trades', opts)
      mash.try(:trades)
    end

    def get_public(method, opts={})
      url = 'https://'+ @base_uri + '/api/' + @api_version + '/public/' + method
      r = self.class.get(url, query: opts)
      JSON.parse(r.body)
    end

    ######################
    ##### Private Data ###
    ######################

    def balance #array of string currency
      get_private 'trading/balance'
    end

    def active_orders opts={}
      #opts parameter
      #symbol (string): Optional parameter to filter active orders by symbol
      get_private 'order', opts
    end

    def cancel_order client_order_id
      delete_private 'order/'+client_order_id
    end

    def trade_history opts={}
      get_private 'history/trades', opts
    end

    def recent_orders opts={}
      get_private 'history/order', opts
    end

    def create_order opts={}
      # clientOrderId	   (String):	Optional parameter, if skipped - will be generated by server. Uniqueness must be guaranteed within a single trading day, including all active orders.
      # symbol	         (String):	Trading symbol
      # side	           (String):	sell buy
      # type	           (String):	Optional. Default - limit. One of: limit, market, stopLimit, stopMarket
      # timeInForce	     (String):	Optional. Default - GDC. One of: GTC, IOC, FOK, Day, GTD
      # quantity	       (Number):	Order quantity
      # price	           (Number):	Order price. Required for limit types.
      # stopPrice	       (Number):	Required for stop types.
      # expireTime	   (Datetime):	Required for GTD timeInForce.
      # strictValidate	(Boolean):	Price and quantity will be checked that they increment within tick size and quantity step. See symbol tickSize and quantityIncrement
      post_private 'order', opts
    end
    ######################
    ##### Payment Data ###
    ######################

    # to be written

    #######################
    #### Generate Signed ##
    ##### Post Request ####
    #######################

    private

    def post_private(method, opts={})
      post_data = encode_options(opts)
      uri = "/api/"+ @api_version + "/" + method
      url = "https://" + @base_uri + uri

      r = self.class.post(url, {basic_auth: {username: @api_key, password: @api_secret}, body: post_data}).parsed_response
      r
    end

    def get_private(method, opts={})
      opts = complete_opts(opts)
      uri = "/api/"+ @api_version + "/" + method +"?" + encode_options(opts)
      url = "https://" + @base_uri + uri

      r = self.class.get(url, basic_auth: {username: @api_key, password: @api_secret})
      JSON.parse(r.body)
    end

    def delete_private(method, opts={})
      post_data = encode_options(opts)
      uri = "/api/"+ @api_version + "/" + method
      url = "https://" + @base_uri + uri

      r = self.class.delete(url, basic_auth: {username: @api_key, password: @api_secret}).parsed_response
      r
    end

    def complete_opts opts
      opts[:apikey] = @api_key
      opts[:nonce] = nonce
      opts
    end

    def nonce
      DateTime.now.strftime('%Q')
    end

    def encode_options(opts)
      uri = Addressable::URI.new
      uri.query_values = opts
      uri.query
    end
  end
end
