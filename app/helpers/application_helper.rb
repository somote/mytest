module ApplicationHelper
  def self.gon_env
    {
        cookieName: Settings.cookie_name,
        serviceRoot: Settings.webapi_root_url,
        proxyRoot: Settings.legacy_webui_root_url,
        webuiUrlRootPath: Settings.webui_url_root_path,
        contentProxyUrlRootPath: Settings.content_proxy_root_url
    }
  end

  def self.get_retailer_names(registries)
    retailer_names = Array.new(registries).delete_if {|registry| registry['Retailer'].nil?}
    retailer_names = retailer_names.map {|registry| registry['Retailer']['Name']}

    if retailer_names.length < 2
      retailer_names.to_s
    else
      retailer_names.take(retailer_names.count - 1).join(', ') << ' and ' << retailer_names.at(retailer_names.count - 1)
    end
  end

  def self.get_couple_name(couple, conn = '&')
    space = ' '
    first = couple['Registrant1FirstName'] + space + couple['Registrant1LastName']
    second = couple['Registrant2FirstName'] +
        (couple['Registrant2LastName'].present? ? space + couple['Registrant2LastName'] : '')

    first << (second.present? ? (space + conn + space + second) : '')
  end

  def self.parse_couple_info(couple, event_date, location)
    {
        username1: "#{couple['Registrant1FirstName']} #{couple['Registrant1LastName']}",
        username2: ("#{couple['Registrant2FirstName']} #{couple['Registrant2LastName']}" unless couple['Registrant2FirstName'].nil? and couple['Registrant2LastName'].nil?),
        eventdate: event_date,
        coupleid: couple['Id'],
        location: location,
        coupleregistries: couple['CoupleRegistries']
    }
  end

  def self.parse_profile_url(couple)
    {
        shortUrl: couple['UniversalRegistry'].nil? ? '' : couple['UniversalRegistry']['ShortUrl'],
        universalRegistryId: couple['UniversalRegistry'].nil? ? '' : couple['UniversalRegistry']['Id'],
        longUrl: couple['UniversalRegistryLongUrl']
    }
  end

  def self.parse_guest_description(couple, event_date, location, retailer_names)
    "#{couple['Registrant1FirstName']}#{couple['Registrant2FirstName'].present? ? ' and ' + couple['Registrant2FirstName'] : ''}
          from #{ location } have registered at #{retailer_names}
          for their wedding on #{ event_date }.
          View all of the items from their registries in one beautiful list."
  end
end
