class Api::OfcController < ApiController
  include ActionController::Cookies
  require File.expand_path("../../../models/ofc/retailer_registry_request", __FILE__)
  require File.expand_path("../../../models/ofc/tk_registry_request", __FILE__)
  require File.expand_path("../../../models/ofc/macys_or_blm_registry", __FILE__)

  def create
    begin
      init_registry_request
      valid_registry_request
      clear_token(params['UserId'], params['RetailerId']) if params['Retry'].nil?
      token = get_token
      retailer_registry = process_retailer_registry(token)
      render json: retailer_registry and return if @rid.nil?
      process_tk_registry
    rescue Exception => e
      render json: {status: :failed, msg: e.message}
    end
  end

  def create_item
    begin
      init_service
      valid_registry_item_request
      token = get_token
      item = @service.create_registry_item(params, token)
      render json: item
    rescue Exception => e
      render json: {status: :failed, msg: e.message}
    end
  end

  private

  def init_registry_request
    init_service
    @retailer_registry_request = RetailerRegistryRequest.new(params)
    @tk_registry_request = TKRegistryRequest.new(params)
  end

  def init_service
    @service = Api::OfcRetailerServiceProvider.get_service(params['RetailerId'])
  end

  def valid_registry_request
    valid_base
    raise 'Params is invalid' if
        not @retailer_registry_request.valid? or
            not @tk_registry_request.valid?
  end

  def valid_registry_item_request
    valid_base
    raise 'Params is invalid' if
        params['sku'].nil? or
            params['quantity'].nil?
  end

  def valid_base
    raise 'Params is invalid' if
        params['UserId'].nil? or
            params['RetailerId'].nil?
    raise 'UnKnow Retailer' if @service.nil?
  end

  def process_retailer_registry(token)
    if params['Retry'].nil?
      retailer_registry = @service.create_retailer_registry(@retailer_registry_request, token)
      @rid = retailer_registry['registryId']
    else
      @rid = params['RetailerRegistryId']
    end
    @tk_registry_request.set_code @rid unless @rid.nil?
    retailer_registry
  end

  def process_tk_registry
    tk_registry = Api::RegistryApi.upsert_retailer_registry(params['UserId'],@tk_registry_request.to_json)
    if tk_registry.status == 200
      render json: JSON.parse(tk_registry.body)
    else
      render json: {status: :failed, msg: tk_registry.body, RetailerRegistryId: @rid}
    end
  end

  def get_token
    code, user_id, retailer_id, service = params['Code'], params['UserId'], params['RetailerId']
    token = get_token_from_cookies(user_id, retailer_id)
    return token if not token.nil? and not token == ''

    refresh_token = get_refresh_token_from_cookies(user_id, retailer_id)
    if not refresh_token.nil? and not refresh_token == ''
      token = get_retailer_token(refresh_token, true, user_id, retailer_id)
    end
    return token if not token.nil? and not token == ''

    get_retailer_token(code, false, user_id, retailer_id)
  end

  def get_retailer_token(code, is_refresh, user_id, retailer_id)
    token = is_refresh ? @service.refresh_token(code) : @service.get_token(code)
    raise 'Authorization code is invalid' if token.nil? or token['access_token'].nil?

    store_token(token['access_token'], user_id, retailer_id)
    store_refresh_token(token['refresh_token'], user_id, retailer_id)
    token['access_token']
  end

  def get_token_from_cookies(user_id, retailer_id)
    cookies["token_#{user_id}_#{retailer_id}"]
  end

  def get_refresh_token_from_cookies(user_id, retailer_id)
    cookies["refresh_token_#{user_id}_#{retailer_id}"]
  end

  def store_token(token, user_id, retailer_id)
    cookies["token_#{user_id}_#{retailer_id}"] = { value: token, expires: 1.hour.from_now }
  end

  def store_refresh_token(refresh_token, user_id, retailer_id)
    cookies["refresh_token_#{user_id}_#{retailer_id}"] = { value: refresh_token, expires: 2.hour.from_now }
  end

  def clear_token(user_id, retailer_id)
    cookies["token_#{user_id}_#{retailer_id}"] = { value: '', expires: Time.at(0) }
    cookies["refresh_token_#{user_id}_#{retailer_id}"] = { value: '', expires: Time.at(0) }
  end
end