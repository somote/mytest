require 'json'
require 'uri'
class ApplicationController < ActionController::Base
  include ConvertHashKeys
  include Member
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def guest
    couple_id = params[:couple_id]

    if /\d+/.match(couple_id)
      couple = Api::RegistryApi.get_couple couple_id

      begin
        couple = JSON.parse(couple.body)
        couple_name = get_couple_name couple
        event_date = Date.parse(couple['EventDate']).strftime('%B %d, %Y')
        location = get_location couple
        retailer_names = get_retailer_names couple['CoupleRegistries']

        @title = couple_name << ' - Wedding Registry'
        @description = "#{couple['Registrant1FirstName']}#{couple['Registrant2FirstName'].present? ? ' and ' + couple['Registrant2FirstName'] : ''}
          from #{ location } have registered at #{retailer_names}
          for their wedding on #{ event_date }.
          View all of the items from their registries in one beautiful list."

        set_gon_for_guest(couple, event_date, location)

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

  def gon_env
    {
        cookieName: Settings.cookie_name,
        serviceRoot: Settings.webapi_root_url,
        proxyRoot: Settings.legacy_webui_root_url,
        webuiUrlRootPath: Settings.webui_url_root_path,
        contentProxyUrlRootPath: Settings.content_proxy_root_url
    }
  end

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

  def get_couple_name(couple, conn = '&')
    space = ' '
    first = couple['Registrant1FirstName'] + space + couple['Registrant1LastName']
    second = couple['Registrant2FirstName'] +
        (couple['Registrant2LastName'].present? ? space + couple['Registrant2LastName'] : '')

    first << (second.present? ? (space + conn + space + second) : '')
  end

  def get_location(couple)
    if /usa?/i.match couple['Country']
      location = "#{couple['City']}, #{couple['State']}"
    else
      location = "#{couple['City']}, #{couple['CountryFullName']}"
    end

    /^[\s,]+$/.match(location) ? '' : location.gsub(/^,\s|,\s$/, '')
  end

  def redirect_to_hub
    redirect_to ''
  end

  def set_gon_for_guest(couple, event_date, location)
    gon.ENV = gon_env
    gon.couple_info = {
        username1: "#{couple['Registrant1FirstName']} #{couple['Registrant1LastName']}",
        username2: ("#{couple['Registrant2FirstName']} #{couple['Registrant2LastName']}" unless couple['Registrant2FirstName'].nil? and couple['Registrant2LastName'].nil?),
        eventdate: event_date,
        coupleid: couple['Id'],
        location: location,
        coupleregistries: couple['CoupleRegistries']
    }
    gon.charity = Api::RegistryApi.fix_charity_url couple['User']['UserCharity']
    gon.personal_websites = couple['PersonalWebsites'].nil? ? [] : couple['PersonalWebsites'].select { |web| [994,950].include? web['AffiliateId']}
    gon.isHiddenProducts = couple['IsHiddenProducts']
    gon.profileURL = {
        shortUrl: couple['UniversalRegistry'].nil? ? '' : couple['UniversalRegistry']['ShortUrl'],
        universalRegistryId: couple['UniversalRegistry'].nil? ? '' : couple['UniversalRegistry']['Id'],
        longUrl: couple['UniversalRegistryLongUrl']
    }
  end
end
