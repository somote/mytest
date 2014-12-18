class Api::OfcController < ApiController
  include ActionController::Cookies
  require File.expand_path("../../../models/ofc/retailer_registry_request", __FILE__)
  require File.expand_path("../../../models/ofc/tk_registry_request", __FILE__)
  require File.expand_path("../../../models/ofc/macys_or_blm_registry", __FILE__)

  def create
    begin
      if params['UserId'].nil? or params['RetailerId'].nil?
        render json: {status: :failed, msg: 'Params is invalid'} and return
      end
      retailer_registry_request = RetailerRegistryRequest.new(params)
      tk_registry_request = TKRegistryRequest.new(params)
      if not retailer_registry_request.valid? or not tk_registry_request.valid?
        render json: {status: :failed, msg: 'Params is invalid'} and return
      end
      clear_token(params['UserId'], params['RetailerId']) if params['Retry'].nil?
      service = Api::OfcRetailerServiceProvider.get_service(params['RetailerId'])
      render json: {status: :failed, msg: 'UnKnow Retailer'} and return if service.nil?
      token = get_token(params['Code'], params['UserId'], params['RetailerId'], service)
      render json: {status: :failed, msg: 'Authorization code is invalid'} and return if token.nil?
      if params['Retry'].nil?
        retailer_registry = service.create_retailer_registry(retailer_registry_request, token)
        rid = retailer_registry['registryId']
      else
        rid = params['RetailerRegistryId']
      end
      render json: retailer_registry and return if rid.nil?
      tk_registry_request.set_code rid
      tk_registry = Api::RegistryApi.upsert_retailer_registry(params['UserId'],tk_registry_request.to_json)
      if tk_registry.status == 200
        render json: JSON.parse(tk_registry.body)
      else
        render json: {status: :failed, msg: tk_registry.body, RetailerRegistryId: rid}
      end
    rescue Exception => e
      render json: {status: :failed, msg: e.message}
    end
  end

  def create_item
    begin
      if params['UserId'].nil? or params['RetailerId'].nil? or params['sku'].nil? or params['quantity'].nil?
        render json: {status: :failed, msg: 'Params is invalid'} and return
      end
      service = Api::OfcRetailerServiceProvider.get_service(params['RetailerId'])
      render json: {status: :failed, msg: 'UnKnow Retailer'} and return if service.nil?
      token = get_token(params['Code'], params['UserId'], params['RetailerId'], service)
      render json: {status: :failed, msg: 'Authorization code is invalid'} and return if token.nil?
      item = service.create_registry_item(params, token)
      render json: item
    rescue Exception => e
      render json: {status: :failed, msg: e.message}
    end
  end

  private

  def get_token(code, user_id, retailer_id, service)
    token = get_token_from_cookies(user_id, retailer_id)
    return token if not token.nil? and not token == ''

    refresh_token = get_refresh_token_from_cookies(user_id, retailer_id)
    if not refresh_token.nil? and not refresh_token == ''
      token = get_retailer_token(refresh_token, true, service, user_id, retailer_id)
    end
    return token if not token.nil? and not token == ''

    get_retailer_token(code, false, service, user_id, retailer_id)
  end

  def get_retailer_token(code, is_refresh, service, user_id, retailer_id)
    token = is_refresh ? service.refresh_token(code) : service.get_token(code)
    return nil if token.nil? or token['access_token'].nil?

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