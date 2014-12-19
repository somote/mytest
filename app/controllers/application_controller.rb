require 'json'
require 'uri'
class ApplicationController < ActionController::Base
  include ConvertHashKeys
  include Member
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  INDEX_TITLE = 'Wedding Registry & Bridal Registries - The Knot'
  INDEX_DESCRIPTION = 'Get tips and trends in wedding registries. Find the top shops to set up your wedding registry and more. Browse through different bridal registries and set up a registry today.'
  MANAGE_TITLE = 'Wedding Gift Registry'
  MANAGE_DESCRIPTION = 'example meta description'

  def index
    @layout_data = TheKnotLayout::Data.new({title: INDEX_TITLE, description: INDEX_DESCRIPTION})
    @xo_metadata = XO::Metadata::Builder.new(application_name: 'Registry')
    @hub = true
    @isLoggedIn = current_member
    gon.ENV = ApplicationHelper.gon_env

    if @isLoggedIn.present?
      @userId = member_id
      response = Api::RegistryApi.get_couples_summary_by_user_id(@userId)
      process_couples_response(response)
    end
  end

  def manage
    gon.ENV = ApplicationHelper.gon_env
    gon.shortenPrefix= Settings.webui_shorten_root_url
    # render page as bvr
    if current_member
      gon.member = current_member.present? ? camelize_hash(current_member.as_json) : {}
    else
      retailers = Api::RegistryApi.get_retailer_to_create_registry
      gon.retailers = JSON.parse retailers.body
    end

    @layout_data = TheKnotLayout::Data.new(title: MANAGE_TITLE, description: MANAGE_DESCRIPTION)
    @leaderboard_ad_hidden = true
  end

  def guest
    couple_id = params[:couple_id]

    if /\d+/.match(couple_id)
      couple = Api::RegistryApi.get_couple couple_id

      begin
        couple = JSON.parse(couple.body)
        couple_params = parse_couple_params(couple)

        @title = couple_name << ' - Wedding Registry'
        @description = ApplicationHelper.parse_guest_description(couple, couple_params)

        set_gon_for_guest(couple, couple_params)

        render layout: false
      rescue
        redirect_to_hub
      end
    else
      redirect_to_hub
    end
  end

  def couple_search
    @coupleSearch = true
    gon.ENV = {
        proxyRoot: Settings.legacy_webui_root_url,
        filterLimit: Settings.couple_search_filter_limit,
        contentProxyUrlRootPath: Settings.content_proxy_root_url
    }
    @xo_metadata = XO::Metadata::Builder.new(application_name: 'Registry Couple Search')
    @layout_data = TheKnotLayout::Data.new(title: 'Registry Couple Search')
    render template: 'application/couple_search'
  end

  private

  def process_couples_response(response)
    if response.present?
      @coupleId = response["CoupleId"]
      @coupleRegistries = {
          registries:process_registries(response["CoupleRegistries"]),
          registries_len:response["NumberOfCoupleRegistries"],
          stats: {
              total: response["NumberOfProducts"],
              fulfilled: response["NumberOfProducts"] - response["NumberOfUnfulfilledProducts"]
          }
      }
      @charity = response["UserCharity"]
    end
  end

  def process_registries(registries)
    temp_registries_array = registries.clone
    temp_registries_array.delete_if {|registry|!registry["LogoImageUrl"].present?}
    if temp_registries_array.length == 0
      registries.slice(0,2)
    else
      proxy = Settings.content_proxy_root_url
      temp_registries_array.slice(0,2).each_with_index { |registry|
        registry["LogoImageUrl"]=proxy + URI.escape(registry["LogoImageUrl"], Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      }
    end
  end

  def redirect_to_hub
    redirect_to ''
  end

  def set_gon_for_guest(couple, couple_params)
    gon.ENV = ApplicationHelper.gon_env
    gon.couple_info = parse_couple_info(couple_params)
    gon.charity = Api::RegistryApi.fix_charity_url couple['User']['UserCharity']
    gon.personal_websites = couple['PersonalWebsites'].nil? ? [] : couple['PersonalWebsites'].select { |web| [994,950].include? web['AffiliateId']}
    gon.isHiddenProducts = couple['IsHiddenProducts']
    gon.profileURL = parse_profile_url(couple)
  end
end
