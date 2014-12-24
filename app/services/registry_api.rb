require 'net/http'
require 'uri'
class Api::RegistryApi < ApiWrapper

  def self.get_couple_info(user_id, current_member = false)
    response = services_conn(Settings.webapi_root_url).get("couples/users/?userId=#{user_id}&eventtype=1")
    begin
      response_body = response.body
      response_body = JSON.parse(response_body)

      if response_body['Id']
        charity = response_body['User']['UserCharity']

        info = {
            couple_info: {
                username1: "#{response_body["Registrant1FirstName"]} #{response_body["Registrant1LastName"]}",
                username2: ("#{response_body["Registrant2FirstName"]} #{response_body["Registrant2LastName"]}" unless response_body["Registrant2FirstName"].nil? and response_body["Registrant2LastName"].nil?),
                eventdate: (Date.parse(response_body["EventDate"]).strftime("%B %d, %Y") unless response_body["EventDate"].nil?),
                coupleid: "#{response_body["Id"]}",
                coupleregistries: response_body["CoupleRegistries"]
            },
            profileURL: {
                shortUrl: response_body['UniversalRegistry'].nil? ? '' : response_body['UniversalRegistry']['ShortUrl'],
                universalRegistryId: response_body['UniversalRegistry'].nil? ? '' : response_body['UniversalRegistry']['Id'],
                longUrl: response_body['UniversalRegistryLongUrl']
            },
            charity: fix_charity_url(charity),
            personal_websites: response_body["PersonalWebsites"],
            isHiddenProducts: response_body["IsHiddenProducts"],
            universal: response_body["UniversalRegistry"]
        }
        unless current_member.equal?(false)
          info['member'] = current_member
        end

        info
      else
        get_charity_by_user_id user_id
      end

    rescue JSON::ParserError
      get_charity_by_user_id user_id
    end
  end

  def self.get_couple(couple_id)
    services_conn(Settings.webapi_root_url).get("couples/#{couple_id}")
  end

  def self.get_charity_by_user_id(user_id)
    begin
      charity_response = services_conn(Settings.webapi_root_url).get("users/#{user_id}/charities")
      charity_response = JSON.parse(charity_response.body)

      if charity_response['UserCharityId']
        {charity: fix_charity_url(charity_response)}
      else
        {}
      end
    rescue Exception
      {}
    end
  end

  def self.fix_charity_url(charity)
    if charity
      charity['CharityUrl'] = charity['CharityUrl'].include?('NonProfitID') ?
          charity['CharityUrl'] : "#{charity['CharityUrl']}&NonProfitID=#{charity['CharityCode'].to_s}"

      charity
    end
  end

  def self.get_retailer_to_create_registry(couple_id = 0)
    proxy_conn.get("/api/registryApiProxy/GetRetailersToCreateRegistry?coupleId=#{couple_id}")
  end

  def self.get_couples_by_search(first_name, last_name, event_month, event_year, event_day)
    proxy_conn.get("/api/CoupleSearchApiProxy/GetCouples?firstName=#{first_name}&lastName=#{last_name}&eventMonth=#{event_month}&eventYear=#{event_year}&eventDay=#{event_day}&eventType=wedding&isUnclaimed=true&IsExactMatchCoupleName=true&isInactive=false&isRegistryCenter=false&isAutoSearch=false")
  end

  def self.hide_personal_website_on_registry(website_params)
    raw_request("/api/registryApiProxy/HidePersonalWebsitesOnRegistryView?#{website_params}")
  end

  def self.getCharityTypes(couple_id, show_top_charities)
    url = "/api/charityApiProxy/GetCharityTypes" + ((couple_id.nil? && show_top_charities.nil?) ? '' : "?coupleId=#{couple_id}&showTopCharities=#{show_top_charities}")
    proxy_conn.get(url)
  end

  def self.selectCharity(couple_id, charity_code, charity_name, charity_url, member_id)
    encode_charity_url = URI.escape(charity_url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    url = "/api/charityApiProxy/SelectCharity?coupleId=#{couple_id}&charityCode=#{charity_code}&charityName=#{charity_name}&charityUrl=#{encode_charity_url}"
    proxy_conn.get(with_member_id(url, member_id))
  end

  def self.updateCharityMessage(couple_id, personal_message, member_id)
    proxy_conn.get(with_member_id("/api/charityApiProxy/UpdateCharityMessage?coupleId=#{couple_id}&message=#{personal_message}", member_id))
  end

  def self.removeCharity(couple_id, member_id)
    proxy_conn.get(with_member_id("/api/charityApiProxy/RemoveCharity?coupleId=#{couple_id}", member_id))
  end

  def self.add_manual_registry(couple_id, registry_name, registry_url, member_id)
    url = "/api/registryApiProxy/AddManualRegistry?coupleId=#{couple_id}&registryName=#{registry_name}&registryUrl=#{registry_url}&isShowRetailer=true"
    proxy_conn.get(with_member_id(url, member_id))
  end

  def self.merge_registry(couple_id, merge_couple_ids, member_id)
    url = "/api/registryApiProxy/MergeCouples?originalCoupleId=#{couple_id}&mergeCoupleIds=#{merge_couple_ids}&isRegistryCenter=false"
    proxy_conn.get(with_member_id(url, member_id))
  end

  def self.check_profile_url(universal_registry_id, short_url)
    proxy_conn.get("/api/registryApiProxy/IsExistedShortUrl?universalRegistryId=#{universal_registry_id}&shortUrl=#{short_url}")
  end

  def self.update_profile_url(couple_id, short_url)
    proxy_conn.get("/api/registryApiProxy/UpdateShortUrl?coupleId=#{couple_id}&shortUrl=#{short_url}")
  end

  def self.update_universal_registry(universal_id, universal)
    host='qa.services.theknot.com'
    path="/registry/v1/universal-registries/#{universal_id}?apikey=#{Settings.webapi_key}"
    req = Net::HTTP::Put.new(path, initheader = {'Content-Type' => 'application/json'})
    req.body = universal.to_json
    response = Net::HTTP.new(host).start { |http| http.request(req) }
    return response
  end

  def self.get_registries(couple_id)
    services_conn(Settings.webapi_root_url).get("couples/#{couple_id}/registries?isRuby=true")
  end

  def self.update_registries(couple_id, registries)
    raw_request("/api/registryApiProxy/UpdateRegistries?coupleId=#{couple_id}&#{registries}")
  end

  def self.hide_products(couple_id, isHiddenProducts)
    proxy_conn.get("/api/registryApiProxy/HideProducts?coupleId=#{couple_id}&isHiddenProducts=#{isHiddenProducts}")
  end

  def self.update_manual_registries(couple_id, registries)
    raw_request("/api/registryApiProxy/UpdateManualRegistries?coupleId=#{couple_id}&#{registries}")
  end

  def self.add_share_log(couple_id, description)
    proxy_conn.post("/api/registryApiProxy/AddLogForShare?coupleId=#{couple_id}&description=#{description}")
  end

  def self.send_staf_mail(mail)
    proxy_conn.post("/api/registryApiProxy/SendEmail?#{mail}")
  end

  def self.raw_request(url)
    url = Settings.legacy_webui_proxyapi_url.to_s + url + "&dbg=true"
    response_body = nil
    open(url, 'Cookie' => ($request_cookies || '')) do |http|
      response_body = http.read
    end
    response_body
  end

  def self.with_member_id(url, member_id)
    if member_id != ''
      url + "&memberId=#{member_id}"
    else
      url
    end
  end

  def self.upsert_retailer_registry(user_id,retailer_registry)
    response = services_conn('http://qa.services.theknot.com/registry/v2/').put("retailerregistries/user/#{user_id}",retailer_registry)
    begin
      return response
    rescue JSON::ParserError => error
      {}
    end
  end

  def self.get_couples_summary_by_user_id(users_id)
    response = services_conn(Settings.webapi_root_url).get("users/#{users_id}/summary?affiliateId=994&quantityOfItem=true")
    begin
      response_body = response.body
      JSON.parse(response_body)
    rescue JSON::ParserError => error
      {}
    end
  end

#  def self.get_couples(first_name,last_name,event_month,event_year,event_type,sort_by,sort_value,limit,offset,location_filter_keys,event_date_filter_keys)
#    proxy_conn.get do |req|
#      req.url "/api/CoupleSearchApiProxy/GetCouplesWithFilters.json"
#      req.params['firstName'] = first_name
#      req.params['lastName'] = last_name
#      req.params['eventMonth'] = event_month
#      req.params['eventYear'] = event_year
#      req.params['eventType'] = event_type
#      req.params['sortBy'] = sort_by
#      req.params['sortValue'] = sort_value
#      req.params['limit'] = limit
#      req.params['offset'] = offset
#      req.params['locationFilterKeys'] = location_filter_keys
#      req.params['eventDateFilterKeys'] = event_date_filter_keys
#    end
#  end

end

